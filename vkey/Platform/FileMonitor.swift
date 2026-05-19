//
//  FileMonitor.swift
//  vkey
//
//  Created by KhanhIceTea on 10/3/24.
//

import Foundation
import os.log

private let log = OSLog(subsystem: "dev.longht.vkey", category: "FileMonitor")

protocol FileMonitorDelegate: AnyObject {
  func didReceive(changes: String)
}

final class FileMonitor {

  let url: URL

  let fileHandle: FileHandle
  let source: DispatchSourceFileSystemObject

  weak var delegate: FileMonitorDelegate?

  init(url: URL) throws {
    self.url = url
    self.fileHandle = try FileHandle(forReadingFrom: url)

    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileHandle.fileDescriptor,
      eventMask: .extend,
      queue: DispatchQueue.main
    )

    source.setEventHandler {
      let event = self.source.data
      self.process(event: event)
    }

    source.setCancelHandler {
      try? self.fileHandle.close()
    }

    fileHandle.seekToEndOfFile()
    source.resume()
  }

  deinit {
    source.cancel()
  }

  func process(event: DispatchSource.FileSystemEvent) {
    guard event.contains(.extend) else {
      return
    }

    let newData = self.fileHandle.readDataToEndOfFile()
    // Non-UTF8 garbage in /tmp/vkey_switch should never crash the IME. Drop
    // the chunk and keep monitoring — the next legitimate write will be a
    // full UTF-8 message we can parse.
    guard let string = String(data: newData, encoding: .utf8) else {
      os_log("FileMonitor: dropping %d non-UTF8 bytes from %@",
             log: log, type: .default, newData.count, url.path)
      return
    }
    self.delegate?.didReceive(changes: string)
  }
}
