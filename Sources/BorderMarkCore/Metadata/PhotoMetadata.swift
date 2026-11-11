import Foundation

/// 从照片 EXIF 中读出的拍摄信息。所有字段都可能缺失（截图、转存图等）。
public struct PhotoMetadata: Equatable, Sendable {
    public var make: String?
    public var model: String?
    public var lens: String?
    public var focalLength: Double?
    public var focalLength35: Double?
    public var fNumber: Double?
    public var exposureTime: Double?
    public var iso: Int?
    public var date: Date?
    public var latitude: Double?
    public var longitude: Double?

    public init(
        make: String? = nil,
        model: String? = nil,
        lens: String? = nil,
        focalLength: Double? = nil,
        focalLength35: Double? = nil,
        fNumber: Double? = nil,
        exposureTime: Double? = nil,
        iso: Int? = nil,
        date: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.make = make
        self.model = model
        self.lens = lens
        self.focalLength = focalLength
        self.focalLength35 = focalLength35
        self.fNumber = fNumber
        self.exposureTime = exposureTime
        self.iso = iso
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
    }
}
