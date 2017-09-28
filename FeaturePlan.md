# About installation medium, runtime SFS, VirtualBox deployment, etc.

The first versions used to deploy the instalation as an 8GiB pendrive image, consisting of the following partitions:
- An optional EFI partition used for booting some machines;
- A big SFS partition, used as the root filesystem, consisting of **etc**, **usr** and **opt**, as well as links and empty directories used to mount the Read/Write partition and entries like **proc**, **sys**, **tmp** and so on;
- A Read/Write partition, including **home**, **root**, **etc** (again), **var** and possibly others.

Since we now use the SFS approach on a day-to-day system and use it to update the system as well, a more elaborated and flexible approach is proposed:

1) the SFS partition is no longer the root -- this means we don't need to store **etc** on it, but means we need to have an unknown set of binaries in order for the system to boot and mount the SFS;
2) the RW partition may include the whole system, which is very usefull to sub-distribution administrators when they are updating and adding or removing packages - when they will drop mounting the SFS partition;
3) the generated SFS may be spread among several machines -- the contents of /etc must be taken into account when new SFSes are spread. Possibly the admin will include his/her /etc on the bundle anyway and clients will decide which changes to pick?
4) the new approach can be used to distribute the installation media
5) updates to distribution files (like **/home/common**) would better be treated by a **tar file** and/or script.

## Conclusion ##

We are better leave this like they are today, until this approach matures. Meaning:
1) If anyone wants to run the system from SFS on a pendrive and have a performance boost, he/she must use the scripts by his/her own;
2) Every user is responsible for updating system packages, although we still provide support for AUR updates
3) Support for distribution updates (like **/home/common**) are not supported -- users must pull changes from *github* and use the provided scripts.