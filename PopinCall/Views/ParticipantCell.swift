import LiveKit
#if canImport(UIKit)
import UIKit

class ParticipantCell: UICollectionViewCell {
    static let reuseIdentifier: String = "ParticipantCell"

    static var instanceCounter: Int = 0

    let cellId: Int

    let videoView: VideoView = {
        let r = VideoView()
        r.layoutMode = .fill
        r.backgroundColor = UIColor.clear.withAlphaComponent(0)
        r.clipsToBounds = true
        r.layer.cornerRadius = 10
        r.layer.masksToBounds = true
        return r
    }()
    
    // Container view with a rounded corner for when there's no video
    let noVideoContainer: UIView = {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.5) // Semi-transparent black
        container.layer.cornerRadius = 10
        container.layer.masksToBounds = true
        container.isHidden = true // Initially hidden
        return container
    }()
    
    let noVideoImage: UIImageView = {
        let n = UIImageView()
        n.image = UIImage(systemName: "video.slash.fill") // Set the image
        n.contentMode = .scaleAspectFit // Better scaling
        n.tintColor = .white // Make the icon visible
        return n
    }()
    
    // Weak reference to the Participant
    weak var participant: Participant? {
        didSet {
            guard oldValue != participant else { return }
            
            if let oldValue {
                // Unsubscribe from previous participant's events in case of reuse
                oldValue.remove(delegate: self)
                videoView.track = nil
            }
            
            if let participant {
                // Listen to participant's events
                participant.add(delegate: self)
                setFirstVideoTrack()
                setNeedsLayout() // Trigger layout update
            }
        }
    }
    
    override init(frame: CGRect) {
        Self.instanceCounter += 1
        cellId = Self.instanceCounter
        
        super.init(frame: frame)
        
        contentView.addSubview(videoView)
        contentView.addSubview(noVideoContainer)
        noVideoContainer.addSubview(noVideoImage)
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Self.instanceCounter -= 1
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        participant = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        videoView.frame = contentView.bounds
        videoView.setNeedsLayout()
        
        noVideoContainer.frame = contentView.bounds
        
        let imageSize = CGSize(width: 30, height: 30)
        noVideoImage.frame = CGRect(
            x: (noVideoContainer.bounds.width - imageSize.width) / 2,
            y: (noVideoContainer.bounds.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
    }
    
    private func setFirstVideoTrack() {
        // Prefer screen share track over camera (matching Android behavior)
        let track = participant?.firstScreenShareVideoTrack ?? participant?.firstCameraVideoTrack
        videoView.track = track
        noVideoContainer.isHidden = (track != nil)
    }
}

extension ParticipantCell: ParticipantDelegate {
    func participant(_: RemoteParticipant, didSubscribeTrack trackPublication: RemoteTrackPublication) {
        DispatchQueue.main.async { [weak self] in
            if (trackPublication.track?.kind == .video) {
                self?.noVideoContainer.isHidden = true
            }
            self?.setFirstVideoTrack()
        }
    }
    
    func participant(_: RemoteParticipant, didUnsubscribeTrack trackPublication: RemoteTrackPublication) {
        DispatchQueue.main.async { [weak self] in
            if (trackPublication.track?.kind == .video) {
                self?.noVideoContainer.isHidden = false
            }
            self?.setFirstVideoTrack()
        }
    }
    
    func participant(_ participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        DispatchQueue.main.async { [weak self] in
            if (trackPublication.track?.kind == .video) {
                self?.noVideoContainer.isHidden = !isMuted
                if isMuted {
                    self?.videoView.isHidden = true
                } else {
                    self?.videoView.isHidden = false
                }
            }
        }
    }
}
#endif
