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

  enum FileMonitorError: Error {
    case cannotOpen
    case notRegularFile
    case notOwnedByCurrentUser
  }

  let url: URL

  let fileHandle: FileHandle
  let source: DispatchSourceFileSystemObject

  weak var delegate: FileMonitorDelegate?

  init(url: URL) throws {
    self.url = url

    // P4: đường dẫn tín hiệu Smart Switch (`/tmp/vkey_switch_<uid>`) nằm trong
    // /tmp world-writable (giữ để tương thích tích hợp launcher). Mở an toàn để
    // chặn tấn công redirect: `O_NOFOLLOW` từ chối symlink ở thành phần cuối, và
    // kiểm tra đây là file thường do đúng user hiện tại sở hữu trước khi tin nội dung.
    let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw FileMonitorError.cannotOpen }
    var st = stat()
    guard fstat(fd, &st) == 0 else {
      close(fd)
      throw FileMonitorError.cannotOpen
    }
    guard (st.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else {
      close(fd)
      throw FileMonitorError.notRegularFile
    }
    guard st.st_uid == getuid() else {
      close(fd)
      throw FileMonitorError.notOwnedByCurrentUser
    }
    self.fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)

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
    // Non-UTF8 garbage in /tmp/vkey_switch_<uid> should never crash the IME. Drop
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
