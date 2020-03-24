//
//  CustomTimer.swift
//  InnoMetricsCollector
//
//  Created by Dragos Strugar on 24.03.2020.
//  Copyright © 2020 Innopolis University. All rights reserved.
//

// idea from here: https://stackoverflow.com/a/30662020

import Foundation

class CustomTimer {
    private var interval = 2 * 60.0 // every 2 minutes
    private var timer: Timer?
    private var repeats: Bool = true
    private var timerEndedCallback: (() -> Void)!
    
    init(interval: Double = 120.0, repeats: Bool = true) {
        self.interval = interval
        self.timer = Timer()
        self.repeats = repeats
    }
    
    public func startTimer(timerEnded: @escaping () -> Void) {
        if self.timer == nil {
            let aSelector: Selector = Selector(("executeInProgressCallback"))
            self.timer = Timer.scheduledTimer(timeInterval: self.interval, target: self, selector: aSelector, userInfo: nil, repeats: true)
            self.timerEndedCallback = timerEnded
        }
    }
    
    public func stopTimer() {
        if self.timer != nil {
            self.timer!.invalidate()
            self.timer = nil
        }
    }
    
    private func executeInProgressCallback() {
        self.timerEndedCallback()
    }
}
