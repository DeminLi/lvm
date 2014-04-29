install: lvm vm
	install lvm /usr/bin
	install vm /usr/bin
lvm: lvm.c
	gcc lvm.c -o lvm
vm: vm.c
	gcc vm.c -o vm
clean:
	rm /usr/bin/lvm
	rm /usr/bin/vm
	rm lvm
	rm vm
