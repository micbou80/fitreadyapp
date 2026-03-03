import UIKit

// MARK: - Result type

struct FoodScanResult {
    let mealName: String
    let kcal: Double
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
}

// MARK: - Errors

enum AnthropicServiceError: LocalizedError {
    case noAPIKey
    case imageEncodingFailed
    case networkError(Error)
    case invalidResponse(Int)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key set. Add your Anthropic API key in Settings."
        case .imageEncodingFailed:
            return "Could not encode the image. Try a different photo."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code):
            return "API returned status \(code). Check your API key."
        case .parseError(let msg):
            return "Could not parse AI response: \(msg)"
        }
    }
}

// MARK: - Service

enum AnthropicService {

    private static let model    = "claude-sonnet-4-6"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let maxSide: CGFloat = 1024

    // MARK: Public

    static func scanFood(
        image: UIImage,
        portionSize: String,   // "small" | "medium" | "large"
        apiKey: String
    ) async throws -> FoodScanResult {

        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AnthropicServiceError.noAPIKey
        }

        // 1. Resize + base64-encode
        guard let b64 = resizedBase64(image) else {
            throw AnthropicServiceError.imageEncodingFailed
        }

        // 2. Build request
        let body: [String: Any] = [
            "model":      model,
            "max_tokens": 256,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type":       "image",
                        "source": [
                            "type":       "base64",
                            "media_type": "image/jpeg",
                            "data":       b64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": prompt(portionSize: portionSize)
                    ]
                ]
            ]]
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey,          forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",    forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 3. Execute
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AnthropicServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AnthropicServiceError.invalidResponse(http.statusCode)
        }

        // 4. Parse
        return try parseResponse(data: data)
    }

    // MARK: Private helpers

    private static func prompt(portionSize: String) -> String {
        """
        You are a precise nutrition analyst. Estimate the macronutrients for the meal in this photo.
        Portion size: \(portionSize).
        Reply ONLY with valid JSON — no extra text, no markdown, no explanation:
        {
          "meal_name": "<brief description of what you see>",
          "kcal": <integer>,
          "protein_g": <integer>,
          "fat_g": <integer>,
          "carbs_g": <integer>
        }
        """
    }

    private static func resizedBase64(_ image: UIImage) -> String? {
        let size = image.size
        let scale: CGFloat
        if max(size.width, size.height) > maxSide {
            scale = maxSide / max(size.width, size.height)
        } else {
            scale = 1.0
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let jpeg = resized?.jpegData(compressionQuality: 0.8) else { return nil }
        return jpeg.base64EncodedString()
    }

    private static func parseResponse(data: Data) throws -> FoodScanResult {
        // Top-level Anthropic response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AnthropicServiceError.parseError("Unexpected response structure")
        }

        // Extract the JSON object from the text (strip any surrounding whitespace/backticks)
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let resultData = stripped.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw AnthropicServiceError.parseError("Could not decode JSON from: \(text.prefix(120))")
        }

        let mealName = result["meal_name"] as? String ?? "Meal"
        let kcal     = (result["kcal"]      as? Double) ?? Double(result["kcal"]      as? Int ?? 0)
        let protein  = (result["protein_g"] as? Double) ?? Double(result["protein_g"] as? Int ?? 0)
        let fat      = (result["fat_g"]     as? Double) ?? Double(result["fat_g"]     as? Int ?? 0)
        let carbs    = (result["carbs_g"]   as? Double) ?? Double(result["carbs_g"]   as? Int ?? 0)

        return FoodScanResult(
            mealName:  mealName,
            kcal:      kcal,
            proteinG:  protein,
            fatG:      fat,
            carbsG:    carbs
        )
    }
}
