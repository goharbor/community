# Pluggable Image Scanning Working Group

The objective of this working group is centralize and focus efforts on 
supporting the ability of Harbor users to choose which container image scanner
they want to use with Harbor directly.

This work is initially identified with [Issue 6234](https://github.com/goharbor/harbor/issues/6234)

Initial [design proposal PR](https://github.com/goharbor/community/pull/98)

## Members

* Zach Hill@Anchore ([zhill](https://github.com/zhill))
* Liz Rice@Aqua Security ([lizrice](https://github.com/lizrice))
* Daniel Pacak@Aqua Security ([danielpacak](https://github.com/danielpacak))
* Steven Zou@VMware ([steven-zou](https://github.com/steven-zou))
* Alex Xu@VMware ([xaleeks](https://github.com/xaleeks))
* Daniel Jiang@VMware ([reasonerjt](https://github.com/reasonerjt))
* Ye Liu@HP ([cafeliker](https://github.com/cafeliker))

## Meetings

| Meeting Date |                 Recordings             |    Minutes                       |
|--------------|----------------------------------------|----------------------------------|
| 2019/10/24   |[Recording](https://VMware.zoom.us/recording/share/9VwDOMhToVdnKhbYX-cHEQIrS-fMZOwL8NEYeqc3hf2wIumekTziMw?startTime=1571921933000)|[Minutes](https://drive.google.com/file/d/1MzFSQHdeNel6VZURFJsZc0yMJTeMVKM9/view?usp=sharing)|
| 2019/10/17   |[Recording](https://VMware.zoom.us/recording/share/hrW94X_3biayZcQLEY-TBwHSqIF4UY-Gslk8Z63dDvOwIumekTziMw?startTime=1571317092000)|[Minutes](https://drive.google.com/file/d/16B7PAB7Kaktre5mGP3zsqOVC-pUPuLUQ/view?usp=sharing)|
| 2019/10/11   |[Recording](https://VMware.zoom.us/recording/share/y0rnDkpzivLnZeMBiRLiui1iv1OlQfdOxl4oX7xbnJCwIumekTziMw?startTime=1570798807000)|[Minutes](https://drive.google.com/file/d/1LnCQBTGuTd8hq-7kEIgRIta4dbL3GOmD/view?usp=sharing)|
| 2019/09/26   |[Recording](https://VMware.zoom.us/recording/share/mJ5m52jjYAqXzy846AdPezAVouuo8rKuqG-E8ULQENSwIumekTziMw?startTime=1569502669000)|[Minutes](https://drive.google.com/file/d/17ZgtnMKpgEnPuN_JsCiuU4diBi7qIlQR/view?usp=sharing)|
| 2019/09/17 | [Recording](https://VMware.zoom.us/recording/share/iw0_yMXw-29MhtrCLHuEfL1FiDRMLtRpQ5kvVulfV8ywIumekTziMw) | [Minutes](https://drive.google.com/file/d/1Smbx7hrwbEg-zLk-God9LjsemQq3y7E1/view?usp=sharing) |
| 2019/09/05 | [Recording](https://vmware.zoom.us/recording/play/h7TObph_9nNX8E0WlxM7bHC1LWwT-FkHn2NtByx9HsGF3NIK0NMWZHQe6_FrtQoq?continueMode=true) | [Minutes](https://drive.google.com/file/d/1szlL_hc2nMhudWeALN93lhKjwglwKKo9/view?usp=sharing) |
| 2019/08/22 | [Recording](https://VMware.zoom.us/recording/share/CrHCTH5G8cL31lCAtjb-ZgwGCNPLdMe7yhtDxFyei8SwIumekTziMw) | [Minutes](https://drive.google.com/open?id=17Apx2zIKUQ8oXA7iHqkKu4rA9XnyN4B3)|
| 2019/08/15   | [Recording](https://vmware.zoom.us/recording/share/unJHiGOBEwcPiSq6GKACqczM5Xphy6BroYMzm6Ds12OwIumekTziMw)| [Minutes](https://drive.google.com/file/d/10JjHLykTmUOaLKg2_czKeMFF8RQd-S50/view?usp=sharing) |
| 2019/08/08   | MISSED~~ | [Minutes](https://drive.google.com/file/d/1-uB-FOIoR562GiS8K7kDryApnad62DNP/view?usp=sharing)|
| 2019/07/25   |[Recording](https://vmware.zoom.us/recording/share/QNuFU34G9zEXUiAqfr4DBhVylBXqepapjfElwiAYrMywIumekTziMw)|[Minutes](https://drive.google.com/open?id=1I2OsIKH15nhgJgBHqAXEZGuYdytEqqAx)|
| 2019/07/18   |[Recording](https://vmware.zoom.us/recording/share/BstyNuO6q7hn48fhoO0iYv4GdwfbFhItUPV0zVcI3WCwIumekTziMw)|[Minutes](https://drive.google.com/open?id=1rJT-W8yw3hearme08DrlSYHRKuVzJ353)|
| 2019/07/11   |[Recording](https://vmware.zoom.us/recording/share/4HQjTnOjf4OjrlK2HXHXRBwn4li7FbWzmFmx4Eo--bSwIumekTziMw?startTime=1562850526000)|[Minutes](https://drive.google.com/open?id=1zj-quucnsFo6Z2VMe25EjJFsDqdvDzkD)|







# Documents
- [1st version of high-level design by Steven Zou@VMware](https://drive.google.com/open?id=1Na17WgMatiU6wFh_K4w-NIcOReC9P386)
- [PoC demo by Daniel Pacak@Aqua Security](https://aquasecurity-my.sharepoint.com/:v:/g/personal/daniel_pacak_aquasec_com/EULA35mJvlZLjAr_sER-PpgB2LJjIoNSpkKUEgnjpYhllg?e=KntmzF)
- [PoC implementation introduction by Daniel Pacak@Aqua Security](https://aquasecurity-my.sharepoint.com/:v:/g/personal/daniel_pacak_aquasec_com/ER-h4qjLIY5Np4OyUN8-KiEBMW74k6LYe_JRNdEyC4xhOg?e=V6d9F0)
- [Orignal PR by Zach Hill@Anchore](https://github.com/goharbor/community/pull/82)
- [Orignal PR by Daniel Pacak@Aqua Security](https://github.com/goharbor/community/pull/90)
