Mutuatech Linux Improvements:
 1) READ CACHE -- uses inotify instead of strace (to monitor all files accessed when running the most used programs); in addition to that, no more archiving & extracting: a simple sequence of touches will do it: touch "$f"; touch "$f" -r "/sfs/$f"
	command: inotifywait -e ACCESS -e OPEN -m -r /usr /opt --format "%e - %w%f"
 2) DESKTOP SUPPORT -- added KDE in addition to JWM, with all scripts reorganized & default configs on /home/common
 3) UPDATES -- Introduced "latest release", to induce clients (inquiring for an update) straight to the latest version (before each update could only be done to the next version); additionally, the official READ CACHE files are release along with each update, so clients have a configurable option of building their caches in-place; adding to that: READ CACHE files are grouped by functionality, so the server may have opt-in (or opt-out) for a READ_CACHE.yt-dlp, for instance
 4) SCRIPT UPDATES -- up until now, only data could be updated -- the Mutuatech scripts were unupdateable. This became, of course, a hassle to support among the increasing number of devices. Now all incarnations of the MutuaTech Linux uses the same set of scripts, which naturally allowed us to automatically manage them on each device.
 5) HOMES -- "home" folder SFS backups are now officially supported: nice scripts & verifications on it, as well as read cache support gathered from the latest run session (manually initiated by the user)



===================
# PRACTICAL STEPS #
===================

Sequence:
	1) Pink -> Old: stop pink, copy dm-0 to 64GiB card, plug pink lap's hd as an external HD on old lap, boot. Once there, prepare the 32GiB pen to receive all torrent & youtube downloads (except for the keep folders) & proceed to copy all the HD contents to the new one. Then, reorganize the old HD to contain our backup.
	2) Mobile -> Copy Titanium backup apk there & restore sygic, waze, maps, radar droid.. ? mabe we may skip waze & maps for they, most certainly, need google play services -- which we don't want
	3) MTL: a script to build a pendrive out of the current running system: MKFS, boot, root scripts, root sfs, home sfs and -- optionally -- apply the caches. A wonderful thing would be to make reusable scripts from this. Apply boot (or zip boot), apply root (or zip root), zip home, apply caches... all of those seem to be reusable.
	4) Proceed to the good way of dertermining the files to cache + validate the touch will do the job we intend it to do. Maybe (b) should be included.
	5) Do the GRUB good theming -- allowing setting variables, like there seems to be in Manjaro. I may start from here: to create a small pendrive, add a custom grub theme to it, try to boot from QEMU

-----------------------

	where are:
	a) The old Linux building scripts? We may get pendrive / file generation from there
	b) The old way of generating caches -- for bcache ? -- in which I inquired pacman for dependencies

-----------------------

Set of our runtime scripts:
	boot         -- functions to generate / install the boot release
	root_scripts -- functions to generate / install the root scripts release
	root_sfs     -- functions to generate / install the root sfs release
	home_sfs     -- functions to backup  / install the home sfs
        read_cache   -- functions to inspect & monitor system usage to determine the best files to be included in the system's read cache. We also have
        release      -- commands to generate & pack together boot, root_scripts & root_sfs into a release #
	update       -- commands to check & install a (possibly existing) new release of boot, root_scripts and root_sfs
	read_cache_builder -- contains commands to start executables so that the read caches may be generated
	bootable_pen -- commands to write to a pendrive the current boot release, current root scripts, current root sfs and to generate a standard home sfs (for commons) and, possibly, a given user
