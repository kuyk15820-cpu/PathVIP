import Foundation

struct RemotePatchService {
    
    enum RemotePatchError: Error {
        case invalidResponse
        case downloadFailed
    }
    
    /// โหลด JSON คอนฟิกจาก Server และดาวน์โหลดไฟล์ใหม่ที่ระบุใน URL
    static func fetchRemotePatch(from apiURL: URL) async throws -> (config: RemotePatchConfig, fileData: Data, fileName: String) {
        // 1. ดึงข้อมูล JSON จาก API
        let (jsonData, jsonResponse) = try await URLSession.shared.data(from: apiURL)
        guard (jsonResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw RemotePatchError.invalidResponse
        }
        
        let config = try JSONDecoder().decode(RemotePatchConfig.self, from: jsonData)
        
        // 2. ดาวน์โหลดไฟล์ใหม่จาก URL ที่ระบุใน JSON
        let (fileData, fileResponse) = try await URLSession.shared.data(from: config.fileURL)
        guard (fileResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw RemotePatchError.downloadFailed
        }
        
        let fileName = config.fileURL.lastPathComponent
        return (config, fileData, fileName)
    }
}
