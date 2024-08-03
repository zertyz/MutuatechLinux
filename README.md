# Mutuatech Linux

Provides `desktop` and `server` packages (and a `common` one as well) to be applied on top of a Garuda Linux install to
bring it to the Mutuatech Linux standards.

Pre and post install instructions of the base Garuda Linux are also available.

# Steps

1. Read xxx before installing Garuda
2. Read xxx after installing Garuda
3. Generate the packages:
```
    . ./publish 
 
```
3. Install the appropriate packages. For example, for a desktop:
```
    paru -U packages/general/*.pkg.tar* packages/desktop/*.pkg.tar*
```
4. Enable the services. Some examples:
```
    systemctl list-unit-files | grep mutuatec
    sudo systemctl enable mutuatech_post_boot
    sudo systemctl enable mutuatech_back_from_suspension
```
5. Edit configs. Example:
```
    vim /root/bin/{config,Performance.local,PowerSave.local}
```
