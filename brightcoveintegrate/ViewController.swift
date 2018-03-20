//

//  ViewController.swift
//  brightcoveintegrate
//
//  Created by Volodymyr Yevdokymov on 3/9/18.
//  Copyright © 2018 PrometheanTV. All rights reserved.
//

import UIKit
import BrightcovePlayerSDK
import BrightcoveIMA
import GoogleInteractiveMediaAds
import PrometheanTVSDK

enum States {
    case playing
    case paused
    case stopped
}

class ViewController: UIViewController {

    //MARK: Outlets
    
    @IBOutlet weak fileprivate var videoContainerView: UIView!
    
    @IBOutlet weak fileprivate var prometheanChannelIdTF: UITextField!
    @IBOutlet weak fileprivate var videoIdTF: UITextField!
    
    @IBOutlet weak fileprivate var playBtn: UIButton!
    @IBOutlet weak fileprivate var pauseBtn: UIButton!
    @IBOutlet weak fileprivate var stopBtn: UIButton!
    
    var ptv_playerController = PrometheanTV.playerController
    var isPaused = false
    var bc_playerConfig:BrightcovePlayerConfig?
    
    // BrightCove
    let bc_account_id = "5687692865001"
    let bc_playerName = "default"
    
    var bc_playbackService: BCOVPlaybackService?
    var bc_playbackController: BCOVPlaybackController?
    var bc_playerView: BCOVPUIPlayerView?
    
    //MARK: - Funcs
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.prometheanChannelIdTF.text = "5aa7d80fe7f165239829bba3"
        self.videoIdTF.text = "5743080499001"
        
        self.ptv_playerController.playbackDelegate = self
        
        self.updateControls(for: .stopped)
        
        self.bc_playerConfig = BrightcovePlayerConfig.configForPlayer(fromAccount: self.bc_account_id,
                                                                             named: self.bc_playerName)
        self.bc_playbackService = BCOVPlaybackService(accountId: self.bc_account_id,
                                                      policyKey: self.bc_playerConfig?.policyKey)
    }

    //MARK: - Actions
    
    @IBAction fileprivate func onPlayDidTap() {
        self.prepareBrightcove()
        self.requestContentFromPlaybackService()
    }

    @IBAction fileprivate func onPauseDidTap() {
        if self.isPaused {
            self.bc_playbackController?.play()
        } else {
            self.isPaused = true
            self.bc_playbackController?.pause()
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                self.updateControls(for: .paused)
            }
        }
    }
    
    @IBAction fileprivate func onStopDidTap() {
        self.bc_playbackController?.pause()
        self.isPaused = false
        self.bc_playerView?.removeFromSuperview()
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.updateControls(for: .stopped)
        }
    }
    
    @IBAction fileprivate func onPlayPTVDidTap() {
        if let ptvid = self.prometheanChannelIdTF.text {
            self.ptv_playerController.containerView = self.videoContainerView
            self.ptv_playerController.play(channelId: ptvid)
            self.ptv_playerController.isPlaybackControlsEnabled = true
        }
    }
    
    //MARK: - Helpers
    
    fileprivate func updateControls(for state:States) {
        self.pauseBtn.setTitle("Pause", for: .normal)

        switch state {
        case .stopped:
            self.playBtn.isEnabled = true
            self.pauseBtn.isEnabled = false
            self.stopBtn.isEnabled = false
        case .playing:
            self.playBtn.isEnabled = false
            self.pauseBtn.isEnabled = true
            self.stopBtn.isEnabled = true
        case .paused:
            self.playBtn.isEnabled = false
            self.pauseBtn.setTitle("Paused/Resume", for: .normal)
            self.pauseBtn.isEnabled = true
            self.stopBtn.isEnabled = true
        }
    }
    
    fileprivate func prepareBrightcove() {
        self.createPlayerView()

        let manager = BCOVPlayerSDKManager.shared()

        let imaSettings = IMASettings()
        imaSettings.ppid = bc_account_id
        imaSettings.language = "en"

        let renderSettings = IMAAdsRenderingSettings()
        renderSettings.webOpenerPresentingController = self;
        renderSettings.webOpenerDelegate = self

        // BCOVIMAAdsRequestPolicy provides methods to specify VAST or VMAP/Server Side Ad Rules. Select the appropriate method to select your ads policy.
        let quePointsPolicy = BCOVCuePointProgressPolicy(processingCuePoints:.processAllCuePoints, resumingPlaybackFrom: BCOVProgressPolicyResumePosition.fromLastProcessedCuePoint, ignoringPreviouslyProcessedCuePoints: true)
        let adsRequestPolicy = BCOVIMAAdsRequestPolicy(fromCuePointPropertiesWithAdTag: self.bc_playerConfig?.imaServerUrl, adsCuePointProgressPolicy: quePointsPolicy)

        self.bc_playbackController = manager?.createIMAPlaybackController(with: imaSettings, adsRenderingSettings: renderSettings, adsRequestPolicy: adsRequestPolicy, adContainer: self.bc_playerView?.contentOverlayView, companionSlots: nil, viewStrategy: nil)
        self.bc_playbackController?.delegate = self
        self.bc_playbackController?.isAutoAdvance = true
        self.bc_playbackController?.isAutoPlay = true
        
        self.bc_playerView?.playbackController = self.bc_playbackController


        self.ptv_playerController.containerView = self.bc_playerView?.controlsStaticView
        self.ptv_playerController.isPlaybackControlsEnabled = false
    }

    fileprivate func createPlayerView() {
        if self.bc_playerView == nil {
            let options = BCOVPUIPlayerViewOptions()
            options.presentingViewController = self

            let controlView = BCOVPUIBasicControlView.withVODLayout()
            // Set playback controller later.
            self.bc_playerView = BCOVPUIPlayerView(playbackController: nil, options: options, controlsView: controlView)
            if let view = self.bc_playerView {
                view.frame = self.videoContainerView.bounds
                view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                self.videoContainerView.addSubview(view)
            }
        }
    }
    
    fileprivate func requestContentFromPlaybackService() {
        self.bc_playbackService?.findVideo(withVideoID: self.videoIdTF?.text ?? "", parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            if let v = video {
                self.bc_playbackController?.setVideos([v] as NSArray)
            } else {
                print("\(#function) - Error retrieving video: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    fileprivate func updateVideoWithVMAPTag(_ video:BCOVVideo?) -> BCOVVideo? {
        let updated = video?.update { (mutableVideo) in
            if let imaTagUrl = self.bc_playerConfig?.imaServerUrl, var propertiesToUpdate = mutableVideo?.properties {
                propertiesToUpdate[kBCOVIMAAdTag] = imaTagUrl
                mutableVideo?.properties = propertiesToUpdate
            }
        }
        return updated
    }
}

extension ViewController: BCOVPlaybackControllerDelegate{
    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didReceive lifecycleEvent:BCOVPlaybackSessionLifecycleEvent) {

    
        if let type = lifecycleEvent.eventType {
            print("\(#function) - \(type)")
            switch type {
            case kBCOVPlaybackSessionLifecycleEventPlay:
                if !self.isPaused {
                    self.updateControls(for: .playing)
                }
                self.isPaused = false
                if let ptvid = self.prometheanChannelIdTF.text {
                    self.ptv_playerController.play(channelId: ptvid, src: nil, platformType: PTVPlatformType.overlaysOnly)
                }
            case kBCOVPlaybackSessionLifecycleEventEnd:
                self.updateControls(for: .stopped)
                self.ptv_playerController.stop()
                self.ptv_playerController.containerView = nil
            case "kBCOVPlaybackSessionLifecycleEventPauseRequest":
                self.isPaused = true
                self.updateControls(for: .paused)
//                self.playerController.pause()
            case kBCOVIMALifecycleEventAdsLoaderLoaded:
                print("\(#function) - Ads loaded.")
            case kBCOVIMALifecycleEventAdsManagerDidReceiveAdEvent:
                print("\(#function) - receive Ad event.")
                let adEvent = lifecycleEvent.properties["adEvent"] as? IMAAdEvent
                switch adEvent?.type {
                case .STARTED?:
                    print("\(#function) - AD is playing")
                case .COMPLETE?:
                    print("\(#function) - Ad Completed.");
                case IMAAdEventType.ALL_ADS_COMPLETED?:
                    print("\(#function) - All ads completed.");
                default: break
                }
            default: break
            }
        }
    }

    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didPassCuePoints cuePointInfo: [AnyHashable : Any]!) {
        if self.bc_playerConfig?.imaUseMediaCuePoints ?? false {
            self.bc_playbackController?.pause()
            self.bc_playbackController?.resumeAd()
        }
    }

    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didEnter ad: BCOVAd!) {
        self.bc_playerView?.contentContainerView.alpha = 0.0
    }

    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didExitAd ad: BCOVAd!) {
        self.bc_playerView?.contentContainerView.alpha = 1.0
    }

    func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
        print("Advanced to new session")
    }
    
    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didProgressTo progress: TimeInterval) {
        print("Progress: \(progress) seconds")

    }
    
    func playbackController(_ controller: BCOVPlaybackController!, didCompletePlaylist playlist: NSFastEnumeration!) {
        self.updateControls(for: .stopped)
        self.ptv_playerController.stop()
    }

}

extension ViewController: IMAWebOpenerDelegate {
    public func webOpenerDidClose(inAppBrowser webOpener: NSObject!) {
        self.bc_playbackController?.resumeAd()
    }
}

extension ViewController: PTVPlayerPlaybackProtocol {
    func player(didChangeToState state: PTVPlayerState) {
        
    }
    
    func player(didPlayTime playTime: Float) {
        
    }
    
    func player(error: PTVPlayerError, description: String?) {
        
    }
    
    func player(didChangeNetworkConnection available: Bool) {
        
    }
    
    func playerShouldContinuePlaybackWhenNetworkConnectionGoesBack() -> Bool {
        return true
    }
    
    
}

