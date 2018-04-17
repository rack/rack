# Rack maintenance

## Supported versions

### New features

New features will only be added to the master branch and will not be made available in point releases.

### Bug fixes

Only the latest release series will receive bug fixes. When enough bugs are fixed and its deemed worthy to release a new gem, this is the branch it happens from.

* Current release series: 2.0.x

### Security issues

The current release series and the next most recent one will receive patches and new versions in case of a security issue.

* Current release series: 2.0.x
* Next most recent release series: 1.6.x

### Severe security issues

For severe security issues we will provide new versions as above, and also the last major release series will receive patches and new versions. The classification of the security issue is judged by the core team.

* Current release series: 2.0.x
* Next most recent release series: 1.6.x
* Last most recent release series: 1.5.x

### Unsupported Release Series

When a release series is no longer supported, it’s your own responsibility to deal with bugs and security issues. We may provide back-ports of the fixes and publish them to git, however there will be no new versions released. If you are not comfortable maintaining your own versions, you should upgrade to a supported version.

## Reporting a bug

All security bugs in Rack should be reported to the core team through our private mailing list [rack-core@googlegroups.com](https://groups.google.com/forum/#!forum/rack-core). Your report will be acknowledged within 24 hours, and you’ll receive a more detailed response to your email within 48 hours indicating the next steps in handling your report.

After the initial reply to your report the security team will endeavor to keep you informed of the progress being made towards a fix and full announcement. These updates will be sent at least every five days, in reality this is more likely to be every 24-48 hours.

If you have not received a reply to your email within 48 hours, or have not heard from the security team for the past five days there are a few steps you can take:

* Contact the current security coordinator [Aaron Patterson](mailto:tenderlove@ruby-lang.org) directly
* Contact the back-up contact [Santiago Pastorino](mailto:santiago@wyeworks.com) directly.

## Disclosure Policy

Rack has a 5 step disclosure policy.

1. Security report received and is assigned a primary handler. This person will coordinate the fix and release process.
2. Problem is confirmed and, a list of all affected versions is determined. Code is audited to find any potential similar problems.
3. Fixes are prepared for all releases which are still supported. These fixes are not committed to the public repository but rather held locally pending the announcement.
4. A suggested embargo date for this vulnerability is chosen and distros@openwall is notified. This notification will include patches for all versions still under support and a contact address for packagers who need advice back-porting patches to older versions.
5. On the embargo date, the [ruby security announcement mailing list](mailto:ruby-security-ann@googlegroups.com) is sent a copy of the announcement. The changes are pushed to the public repository and new gems released to rubygems.

Typically the embargo date will be set 72 hours from the time vendor-sec is first notified, however this may vary depending on the severity of the bug or difficulty in applying a fix.

This process can take some time, especially when coordination is required with maintainers of other projects. Every effort will be made to handle the bug in as timely a manner as possible, however it’s important that we follow the release process above to ensure that the disclosure is handled in a consistent manner.

## Receiving Security Updates

The best way to receive all the security announcements is to subscribe to the [ruby security announcement mailing list](mailto:ruby-security-ann@googlegroups.com). The mailing list is very low traffic, and it receives the public notifications the moment the embargo is lifted. If you produce packages of Rack and require prior notification of vulnerabilities, you should be subscribed to vendor-sec.

No one outside the core team, the initial reporter or vendor-sec will be notified prior to the lifting of the embargo. We regret that we cannot make exceptions to this policy for high traffic or important sites, as any disclosure beyond the minimum required to coordinate a fix could cause an early leak of the vulnerability.

## Comments on this Policy

If you have any suggestions to improve this policy, please send an email the core team at [rack-core@googlegroups.com](https://groups.google.com/forum/#!forum/rack-core).
