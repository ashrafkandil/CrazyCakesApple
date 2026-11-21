import Foundation

/// Submit review result
struct SubmitReviewResult {
    let isSuccess: Bool
    let errorMessage: String?
}

/// Email notification result
struct EmailNotificationResult {
    let isSuccess: Bool
    let errorMessage: String?
}

/// SMS notification result
struct SmsNotificationResult {
    let isSuccess: Bool
    let errorMessage: String?
}

/// API client for server communication
final class ApiClient {
    static let shared = ApiClient()

    private let baseURL: String

    private init() {
        self.baseURL = AppConfig.apiBaseURL
    }

    /// Submit a new review
    func submitReview(author: String, quote: String, rating: Int) async -> SubmitReviewResult {
        guard let url = URL(string: "\(baseURL)/reviews") else {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let requestBody = [
            "author": author,
            "quote": quote,
            "rating": rating
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Failed to encode request")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid response")
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return SubmitReviewResult(isSuccess: true)
            } else {
                let errorMessage: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "Failed to submit review"
                }
                return SubmitReviewResult(isSuccess: false, errorMessage: errorMessage)
            }
        } catch {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Network error: \(error.localizedDescription)")
        }
    }

    /// Approve a pending review
    func approveReview(id: Int) async -> SubmitReviewResult {
        guard let url = URL(string: "\(baseURL)/reviews/\(id)/approve") else {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid response")
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return SubmitReviewResult(isSuccess: true)
            } else {
                let errorMessage: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "Failed to approve review"
                }
                return SubmitReviewResult(isSuccess: false, errorMessage: errorMessage)
            }
        } catch {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Network error: \(error.localizedDescription)")
        }
    }

    /// Delete a review
    func deleteReview(id: Int) async -> SubmitReviewResult {
        guard let url = URL(string: "\(baseURL)/reviews/\(id)") else {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return SubmitReviewResult(isSuccess: false, errorMessage: "Invalid response")
            }

            if httpResponse.statusCode == 200 {
                return SubmitReviewResult(isSuccess: true)
            } else {
                let errorMessage: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "Failed to delete review"
                }
                return SubmitReviewResult(isSuccess: false, errorMessage: errorMessage)
            }
        } catch {
            return SubmitReviewResult(isSuccess: false, errorMessage: "Network error: \(error.localizedDescription)")
        }
    }

    /// Check if email notifications are enabled
    func areEmailNotificationsEnabled() async -> Bool {
        // This would typically call an API endpoint or check local settings
        // For now, return true as default (can be enhanced to check from server)
        return true
    }

    /// Send email notification for new review
    func sendEmailNotification(author: String, quote: String, rating: Int, reviewId: Int) async -> EmailNotificationResult {
        // Check if email notifications are enabled
        let enabled = await areEmailNotificationsEnabled()
        guard enabled else {
            return EmailNotificationResult(isSuccess: false, errorMessage: "Email notifications disabled")
        }

        // In a real implementation, this would call an API endpoint to send the email
        // For now, we'll just log it
        print("Email notification would be sent for review \(reviewId) from \(author)")
        return EmailNotificationResult(isSuccess: true)
    }

    /// Send SMS notification for new contact form submission
    func sendSmsNotification(name: String, eventType: String, eventDate: String) async -> SmsNotificationResult {
        guard let url = URL(string: "\(baseURL)/contact/sms-notify") else {
            return SmsNotificationResult(isSuccess: false, errorMessage: "Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let requestBody = [
            "name": name,
            "eventType": eventType,
            "eventDate": eventDate
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return SmsNotificationResult(isSuccess: false, errorMessage: "Failed to encode request")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return SmsNotificationResult(isSuccess: false, errorMessage: "Invalid response")
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return SmsNotificationResult(isSuccess: true)
            } else {
                let errorMessage: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "Failed to send SMS notification"
                }
                return SmsNotificationResult(isSuccess: false, errorMessage: errorMessage)
            }
        } catch {
            return SmsNotificationResult(isSuccess: false, errorMessage: "Network error: \(error.localizedDescription)")
        }
    }
}