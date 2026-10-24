#!/usr/bin/env node
/**
 * Syncs the React Native mobile content into this native iOS project:
 *
 *   1. packs data/crazy-cakes.db from CrazyCakesMobile into
 *      CrazyCakes/Resources/crazy-cakes.db (a single, WAL-free file),
 *   2. copies assets/images and assets/videos into the app's resource folders,
 *   3. regenerates CrazyCakes/Core/MediaRegistry.swift from
 *      scripts/MediaRegistry.template.swift so every database media path maps to the
 *      bundled file.
 *
 * Usage (Node 22.5+ for node:sqlite):
 *   node scripts/sync-content.mjs
 *   node scripts/sync-content.mjs --mobile ../CrazyCakesMobile
 */

import { createHash } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mobileFlagIndex = process.argv.indexOf("--mobile");
const mobileRoot = path.resolve(
  projectRoot,
  mobileFlagIndex >= 0 ? process.argv[mobileFlagIndex + 1] : path.join("..", "CrazyCakesMobile"),
);

const databaseSource = path.join(mobileRoot, "data", "crazy-cakes.db");
const imagesSource = path.join(mobileRoot, "assets", "images");
const videosSource = path.join(mobileRoot, "assets", "videos");

const resources = path.join(projectRoot, "CrazyCakes", "Resources");
const databaseTarget = path.join(resources, "crazy-cakes.db");
const imagesTarget = path.join(resources, "Images");
const videosTarget = path.join(resources, "Videos");
const registryTarget = path.join(projectRoot, "CrazyCakes", "Core", "MediaRegistry.swift");
const registryTemplate = path.join(projectRoot, "scripts", "MediaRegistry.template.swift");

if (!existsSync(databaseSource)) {
  throw new Error("Mobile database not found at " + databaseSource + ". Pass --mobile <path-to-CrazyCakesMobile>.");
}
if (!existsSync(imagesSource)) {
  throw new Error("Mobile media not found at " + imagesSource + ".");
}

function normalize(key) {
  let value = String(key).split("?")[0].replaceAll("\\", "/");
  try {
    value = decodeURIComponent(value);
  } catch {
    // keep the raw path when it is not percent-encoded
  }
  const dot = value.lastIndexOf(".");
  const slash = value.lastIndexOf("/");
  return dot > slash ? value.slice(0, dot) + value.slice(dot).toLowerCase() : value;
}

function filesUnder(directory, base = directory, acc = []) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) filesUnder(fullPath, base, acc);
    else acc.push(path.relative(base, fullPath).split(path.sep).join("/"));
  }
  return acc;
}

function freshDirectory(directory) {
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
}

function swiftMap(entries) {
  return Object.keys(entries)
    .sort()
    .map((key) => "        " + JSON.stringify(key) + ": " + JSON.stringify(entries[key]) + ",")
    .join("\n");
}

// 1. Pack the database into a single file (no -wal / -shm sidecars).
rmSync(databaseTarget + ".next", { force: true });
const packer = new DatabaseSync(databaseSource, { readOnly: true });
try {
  const vacuumTarget = (databaseTarget + ".next").replace(/'/g, "''");
  packer.exec("VACUUM INTO '" + vacuumTarget + "'");
} finally {
  packer.close();
}
rmSync(databaseTarget, { force: true });
renameSync(databaseTarget + ".next", databaseTarget);

const databaseBytes = readFileSync(databaseTarget);
const databaseSha = createHash("sha256").update(databaseBytes).digest("hex");

// 2. Copy media, flattened: bundled file names are unique.
freshDirectory(imagesTarget);
const images = {};
for (const relativePath of filesUnder(imagesSource)) {
  const fileName = path.basename(relativePath);
  copyFileSync(path.join(imagesSource, relativePath), path.join(imagesTarget, fileName));
  images[normalize("/assets/crazy/" + relativePath)] = fileName;
}

freshDirectory(videosTarget);
const videos = {};
if (existsSync(videosSource)) {
  for (const entry of readdirSync(videosSource, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    copyFileSync(path.join(videosSource, entry.name), path.join(videosTarget, entry.name));
    videos[normalize("/assets/videos/" + entry.name)] = entry.name;
  }
}

// 3. Verify the database references only media that is now bundled.
const database = new DatabaseSync(databaseTarget, { readOnly: true });
const rows = [
  ...database.prepare("SELECT src FROM images").all(),
  ...database.prepare("SELECT src FROM videos").all(),
];
const integrity = database.prepare("PRAGMA integrity_check").get();
const stats = {
  categories: database.prepare("SELECT count(*) AS count FROM categories").get().count,
  images: database.prepare("SELECT count(*) AS count FROM images").get().count,
  videos: database.prepare("SELECT count(*) AS count FROM videos").get().count,
  testimonials: database.prepare("SELECT count(*) AS count FROM testimonials WHERE published = 1").get().count,
  content: database.prepare("SELECT count(*) AS count FROM content").get().count,
  eventTypes: database.prepare("SELECT count(*) AS count FROM event_types").get().count,
  socialLinks: database.prepare("SELECT count(*) AS count FROM social_links WHERE active = 1").get().count,
};
database.close();

if (integrity?.integrity_check !== "ok") {
  throw new Error("Packed database failed integrity_check: " + (integrity?.integrity_check ?? "no result"));
}
const missing = rows.map((row) => normalize(row.src)).filter((key) => !(key in images) && !(key in videos));
if (missing.length > 0) {
  throw new Error("Database references media missing from the mobile project: " + missing.join(", "));
}

// 4. Regenerate the media registry.
const template = readFileSync(registryTemplate, "utf8");
const registry = template
  .replace("// __IMAGES__", swiftMap(images).replace(/^/, ""))
  .replace("// __VIDEOS__", swiftMap(videos));
writeFileSync(registryTarget, registry, "utf8");

const lines = [
  "Native content synced from " + mobileRoot,
  "  database  " + (statSync(databaseTarget).size / 1024).toFixed(1) + " KB  sha256=" + databaseSha,
  "  media     " + Object.keys(images).length + " images, " + Object.keys(videos).length + " videos",
  "  rows      categories=" + stats.categories + " images=" + stats.images + " videos=" + stats.videos +
    " testimonials=" + stats.testimonials + " content=" + stats.content +
    " eventTypes=" + stats.eventTypes + " socialLinks=" + stats.socialLinks,
];
console.log(lines.join("\n"));
