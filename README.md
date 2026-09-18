# WinServerTools

A collection of PowerShell automation tools for managing multiple Windows servers at once.

---

## Tools

### [PS-MultiServerFileCopy](PS-MultiServerFileCopy/) — Available now
Copies a file or folder to multiple Windows servers in a single run. Validates servers, retries failures, and logs every operation.

### [PS-MultiServerConfigCollector](PS-MultiServerConfigCollector/) — In development
Collects hardware and configuration details (CPU, RAM, disk, OS) from multiple servers and exports them to a single report.

### [PS-SystemUsageCollector](PS-SystemUsageCollector/) — In development
Exports real-time usage metrics (CPU, memory, disk I/O) from multiple servers — similar to Task Manager but across your entire server fleet.

---

## Requirements

- Windows PowerShell 5.1 or later
- Network access to target servers
- Appropriate Windows permissions on each server

---

## License

MIT. See [LICENSE](LICENSE).
