import Foundation

struct RemotePatchConfig: Decodable {
    let patchID: String
    let projectName: String
    let targetBundleID: String
    let targetPath: String
    let fileURL: URL
    let version: String // 1. เพิ่มบรรทัดนี้
    
    enum CodingKeys: String, CodingKey {
        case patchID = "patch_id"
        case projectName = "project_name"
        case targetBundleID = "target_bundle_id"
        case targetPath = "target_path"
        case fileURL = "file_url"
        case version // 2. เพิ่มบรรทัดนี้ (ถ้าใน JSON ชื่อไม่ตรงกัน ให้ระบุ เช่น case version = "v_code")
    }
}
