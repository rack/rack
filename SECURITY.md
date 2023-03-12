# Security Policy

## Supported versions

The current release series and the next most recent one (by major-minor version) will receive patches and new versions in case of a security issue.

### Unsupported Release Series

When a release series is no longer supported, it’s your own responsibility to deal with bugs and security issues. If you are not comfortable maintaining your own versions, you should upgrade to a supported version.

## Reporting a security issue

Contact the current security coordinator [Aaron Patterson](mailto:tenderlove@ruby-lang.org) directly. If you do not get a response within 7 days, create an issue on the relevant project without any specific details and mention the project maintainers.

## Disclosure Policy

1. Security report received and is assigned a primary handler. This person will coordinate the fix and release process.
2. Problem is confirmed and, a list of all affected versions is determined. Code is audited to find any potential similar problems.
3. Fixes are prepared for all releases which are still supported. These fixes are not committed to the public repository but rather held locally pending the announcement.
4. A suggested embargo date for this vulnerability is chosen and distros@openwall is notified. This notification will include patches for all versions still under support and a contact address for packagers who need advice back-porting patches to older versions.
5. On the embargo date, the changes are pushed to the public repository and new gems released to rubygems.

This process can take some time, especially when coordination is required with maintainers of other projects. Every effort will be made to handle the bug in as timely a manner as possible, however it’s important that we follow the release process above to ensure that the disclosure is handled in a consistent manner.
