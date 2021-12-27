//
//  LoopSampler.swift
//  LoopSamplerDemo
//
//  Created by Joshua Teitelbaum on 12/26/21.
//

import Foundation
import AVFoundation

let DEFAULT_LOOP_VOICES = 10
let BUFFER_DURATION = 0.005
let DEFAULT_VOLUME = 0.8
let MAX_LOOPS = 3

 class Sample : NSObject {
    var id:Int!
    var url:URL!
    var shortName:String!
    var audioFile:AVAudioFile?
    var valid = false
     
    init(id:Int, url:URL) {
        super.init()
        self.id = id
        self.url = url
        
        do {
            _ = self.url.startAccessingSecurityScopedResource()
            self.audioFile = try AVAudioFile(forReading: self.url)
            self.shortName  = url.lastPathComponent
            self.url.stopAccessingSecurityScopedResource()
            valid = true
        } catch {
           valid = false
        }
    }
}

class Loop : NSObject {

    var id:Int!
    var mixer = AVAudioMixerNode()
    var voices: [AVAudioPlayerNode?]!
    var voiceSamplePool:[Int:Int]! ///SampleId to Voice index
    var armed:Bool!
    var playing:Bool!
    var recording:Bool!
    
    var scheduledEvents:[Any?]!
    
    init(id:Int, voiceCount:Int = DEFAULT_LOOP_VOICES) {
        super.init()
        self.id = id
        self.armed = false
        self.playing = false
        voices = [AVAudioPlayerNode]()
        for _ in (0...voiceCount) {
            let avPlayerNode = AVAudioPlayerNode()
            voices.append(avPlayerNode)
        }
        self.scheduledEvents = [Any?]()
        self.voiceSamplePool = [Int:Int]()
        
        _attachVoicesToMainEngine()
    }
    
    func engine() -> AVAudioEngine?{
        return LoopSampler.shared.engine
    }
    
    func isPlaying() -> Bool {
        return playing
    }
    
    func isRecording() -> Bool {
        return armed && playing
    }
    /// _attachVoicesToMainEngine
    /// Internal method to wire up:
    func _attachVoicesToMainEngine() {
        for v in voices {
            engine()?.attach(v!)
        }
        engine()?.attach(self.mixer)
        
        for v in voices {
            engine()?.connect(v!, to: self.mixer, format: nil)
        }
       
        engine()?.connect(self.mixer, to: engine()!.mainMixerNode, format: nil
                                        /*format: audioPhile.processingFormat*/)
        self.mixer.volume = Float(DEFAULT_VOLUME)
        self.mixer.outputVolume = Float(DEFAULT_VOLUME)
    }
    
    func _stopAllPlayerNodes() {
        objc_sync_enter(voiceSamplePool as Any)
        for voice in voices {
            voice?.stop()
        }
        voiceSamplePool.removeAll()
        objc_sync_exit(voiceSamplePool as Any)
    }
    
    func _lockVoiceForSamplePlay(sampleId:Int) -> Int?{
        objc_sync_enter(voiceSamplePool as Any)
        let idx = voiceSamplePool.keys.firstIndex(of: sampleId)
        if idx != nil {
            let retval =  voiceSamplePool[sampleId]
            objc_sync_exit(voiceSamplePool as Any)
            return retval
        }
        let lockedCount = voiceSamplePool.keys.count
        if lockedCount >= voices.count {
            objc_sync_exit(voiceSamplePool as Any)
            return nil
        }
        voiceSamplePool[sampleId] = lockedCount
        objc_sync_enter(voiceSamplePool as Any)
        return lockedCount
    }
    
    func _unlockVoiceForSamplePlay(sampleId:Int) {
        objc_sync_enter(voiceSamplePool as Any)
        let idx = voiceSamplePool.keys.firstIndex(of: sampleId)
        if idx != nil {
            voiceSamplePool.remove(at: idx!)
        }
        objc_sync_exit(voiceSamplePool as Any)
        
    }
    func removeScheduledEvents() {
        scheduledEvents.removeAll()
    }
    func play() {
        playing = true
        print ("Loop \(self.id!) \(playing)")
    }
    
    /// playsSampleImmediate:
    /// Plays the sample right away.  If it's the same sample, then it gets cut off because it employs the same player node that is currently affine to the sample.
    /// This behaviour could change by changing the locking mechanism.  If you retruned a node per request that was based on availability then it would be polyphonic on the same sample id.
    func playSampleImmediate(sampleId:Int) {
        let sample = LoopSampler.shared._getSample(sampleId: sampleId)
        if sample == nil {
            return
        }
        
        let idx = _lockVoiceForSamplePlay(sampleId: sample!.id)
        if idx == nil {
            return
        }
        let vox = voices[idx!]
       
        let frameLength = sample!.audioFile!.length
        let framesToPlay =  AVAudioFrameCount(frameLength)
        vox!.prepare(withFrameCount: framesToPlay)
        vox!.stop()
        vox!.prepare(withFrameCount: framesToPlay)
        vox!.scheduleSegment( sample!.audioFile!,
                                    startingFrame: 0,
                                    frameCount: framesToPlay,
                                    at: nil,
                                    completionCallbackType: .dataPlayedBack)
                { cbType in
                    DispatchQueue.main.async { [weak self] in
                       
                        self?._unlockVoiceForSamplePlay(sampleId: sampleId)
                    }
                }
        /*
         If for whatever reason the damn engine light came on....and stopped
         Start it up again.  It happens during the course of playing or anything!
         */
        _ = LoopSampler.shared.ignite()
        /*
         If the node is busy or the engine isn't running well...get out of here.
         Don't touch the node yet.
         */
        if vox!.isPlaying || !engine()!.isRunning { return }
        vox!.play()
    }
    func stop() {
        for v in voices {
            v?.stop()
        }
        playing = false
        recording = false
        
        print ("Loop id \(self.id) stopped")
    }
    func record() {
        stop()
        disarm()
        removeScheduledEvents()
        arm()
        recording = true
    }
    func disarm() {
        armed = false
    }
    func arm() {
        disarm()
        armed = true
    }
}


public class LoopSampler {
    
    static var shared = LoopSampler()
    
    var engine = AVAudioEngine()
    let mixer = AVAudioMixerNode()
    var immediateLoop:Loop?
    var samples:[Int:Sample]!
    var loops:[Int:Loop]!
    
    var loopIDCount = 0
    var sampleIDCount = 0
    
    
    private func _setupAudioSession() {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(BUFFER_DURATION)
        } catch {
            fatalError("Could not setup audio session")
        }
    }
   
    init() {
        samples = [Int:Sample]()
        loops = [Int:Loop]()
        _setupAudioSession()
    }
    
    public func ignite() ->Bool {
        if immediateLoop == nil {
            immediateLoop = Loop(id: -1)
        }
        if !engine.isRunning {
            let hardwareFormat = self.engine.outputNode.outputFormat(forBus: 0)
            self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: hardwareFormat)
            do {
                engine.prepare()
                try self.engine.start()
            } catch {
                fatalError("Failed to start the audio engine. This is definitely Apple's fault.")
            }
        }
        return true
    }
    
    public func isPlayingOrRecording()->Bool {
        for l in loops {
            if l.value.isPlaying() || l.value.isRecording() {
                return true
            }
        }
        return false
    }
    func _getSample(sampleId:Int) ->Sample? {
        let i = samples.firstIndex(where: {(id, l) in return sampleId == id})
        if i == nil {
            return nil
        }
        return samples[sampleId]
    }
    
    func _getLoop(loopId:Int) -> Loop? {
        let i = loops.firstIndex(where: {(id, l) in return loopId == id})
        if i == nil {
            return nil
        }
        return loops[loopId]
    }
    public func playSampleImmediate(sampleId:Int, loopId:Int? = nil) {
        let theLoop  = loopId == nil ? immediateLoop : _getLoop(loopId: loopId!)
        if theLoop == nil {
            return
        }
        theLoop!.playSampleImmediate(sampleId: sampleId)
    }
    public func playSampleImmediate(sampleName:String, loopId:Int? = nil) {
        let s = shortNameToSampleId(shortName: sampleName)
        if s == nil {
            return
        }
        playSampleImmediate(sampleId: s!, loopId: loopId)
    }
    
    public func createLoop() ->Int?{
        if loops == nil {
            loops = [Int:Loop]()
        }
        if loops.count >= MAX_LOOPS {
            return nil
        }
        let loop = Loop(id:loopIDCount)
        loops[loopIDCount] = loop
        loopIDCount += 1
        return loop.id
    }
    
    public func deleteAllLoops() {
        if loops == nil {
            return
        }
        stopAllLoops()
        for l in loops {
            l.value.stop()
        }
        let keys = loops.keys
        for k in keys {
            deleteLoop(loopId: k)
        }
       
    }
    public func deleteLoop(loopId:Int) {
        if loops == nil {
            return
        }
        let idx = loops.firstIndex(where: {(id, value) in return loopId == id})
        if idx == nil {
            return
        }
        loops[loopId]?.stop()
        loops.removeValue(forKey: loopId)
        return
    }
    
    public func playLoop(loopId:Int) {
        if loops == nil {
            return
        }
        let idx = loops.firstIndex(where: {(id, value) in return loopId == id})
        if idx == nil {
            return
        }
        loops[loopId]?.play()
    }
    
    public func armLoop(loopId:Int) {
        if loops == nil {
            return
        }
        let idx = loops.firstIndex(where: {(id, value) in return loopId == id})
        if idx == nil {
            return
        }
        loops[loopId]?.arm()
    }
    
    public func disarmLoop(loopId:Int) {
        if loops == nil {
            return
        }
        let idx = loops.firstIndex(where: {(id, value) in return loopId == id})
        if idx == nil {
            return
        }
        loops[loopId]?.disarm()
    }
    
    public func playAllLoops() {
        if loops == nil {
            return
        }
        stopAllLoops()
        for l in loops {
            l.value.play()
        }
    }
    
    public func stopAllLoops() {
        if loops == nil {
            return
        }
        for l in loops.values {
            l.stop()
        }
    }
    
    public func shortNameToSampleId(shortName:String) -> Int? {
        let s = samples.first(where: {(id, s) in  return s.shortName == shortName })
        if s == nil {
            return nil
        }
        return s!.key
    }
    
    public func registerSample(sampleURL:URL) -> Int? {
        let s = Sample(id: sampleIDCount, url: sampleURL)
        if s.valid {
            samples[sampleIDCount] = s
            sampleIDCount += 1
            return s.id
        }
        return nil
    }
    
    public func _stopAllLoopsPlayingSample(sampleId:Int) {
        print ("you should do this")
    }
    public func _clearAllLoopsReferencingSample(sampleId:Int) {
        print ("you should do this")
    }
    public func unregisterSample(sampleId:Int) {
        let s = samples.firstIndex(where: {(key, value) in  key == sampleId})
        if s == nil {
            return
        }
        _stopAllLoopsPlayingSample(sampleId: sampleId)
        _clearAllLoopsReferencingSample(sampleId: sampleId)
        samples.removeValue(forKey: sampleId)
        return
    }
    
    public func unregisterAllSamples() {
        let keys = samples.keys
        for key in keys {
            unregisterSample(sampleId: key)
        }
        return
    }
    
    public func getAllSampleIDs() -> [(Int,String)] {
        var ret = [(Int,String)]()
        
        for key in samples.keys {
            if samples[key] != nil {
                ret.append((samples[key]!.id, samples[key]!.shortName))
            }
        }
        return ret
    }
}
