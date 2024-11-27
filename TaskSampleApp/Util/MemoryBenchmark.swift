//
//  MemoryBenchmark.swift
//  TaskSampleApp
//
//  Created by MEGA_Mac on 11/27/24.
//

import Foundation

final class MemoryBenchmark {
    static func measureMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            print("Error with task_info(): \(kerr)")
            return 0
        }
        
        return Int64(info.resident_size)
    }
    
    static func trackMemoryUsage(for operation: () async throws -> Void) async {
        let startMemory = measureMemoryUsage()
        print("시작 메모리: \(ByteCountFormatter.string(fromByteCount: startMemory, countStyle: .memory))")
        
        do {
            try await operation()
        } catch {
            print("Operation failed: \(error)")
        }
        
        let endMemory = measureMemoryUsage()
        print("종료 메모리: \(ByteCountFormatter.string(fromByteCount: endMemory, countStyle: .memory))")
        
        let memoryDelta = endMemory - startMemory
        print("메모리 사용량 변화: \(ByteCountFormatter.string(fromByteCount: memoryDelta, countStyle: .memory))")
    }
}

