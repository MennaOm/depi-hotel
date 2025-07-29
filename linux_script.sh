 cp assignment.txt ass.txt
 mv ass.txt moved.txt
 mv test.txt tst.txt
 history | tail -n 20 | awk '{$1=""; print $0}' > linux_script.sh
