import Foundation

struct PatchPackageBuilder {
    
    /// ประกอบข้อมูลจาก Server เป็น PatchProject แล้ว Encode เป็น Data นามสกุล .3105
    static func buildPackageData(
        from config: RemotePatchConfig,
        fileData: Data,
        fileName: String
    ) throws -> Data {
        
        // 1. สร้าง Rule ล็อก Bundle ID และ Path
        let rule = PatchRule(
            id: UUID(uuidString: config.patchID) ?? UUID(),
            bundleID: config.targetBundleID,
            relativePath: config.targetPath,
            replacementFilename: fileName,
            replacementData: fileData
        )
        
        // 2. ประกอบเป็น Project Object
        let project = PatchProject(
            id: UUID(uuidString: config.patchID) ?? UUID(),
            name: config.projectName,
            createdAt: Date(),
            updatedAt: Date(),
            bundleIdentifiers: [config.targetBundleID],
            directories: [],
            rules: [rule]
        )
        
        // 3. เรียกใช้ encodeNew ของเดิม แล้วดึงค่า .data ออกมา
        let encodedPackage = try PatchPackageCodec.encodeNew(
            project: project,
            password: nil
        )
        
        return encodedPackage.data
    }
}
