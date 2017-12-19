all: u-boot.scr

u-boot.scr: u-boot.script
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n de1-soc -d $< $@

clean:
	rm -rf u-boot.scr
