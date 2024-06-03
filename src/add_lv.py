# add_lv.py
import sys

def modify_line(line_number, lv_file, target_file):
    live_variables = []

    with open(lv_file, 'r') as file:
        for line in file:
            live_variables.append(line.strip())  # 공백 제거 후 추가

    with open(target_file, 'r') as file:
        lines = file.readlines()

    modification = " + ".join([f"({lv} != {lv} ? 1 : 0)" for lv in live_variables])
    lines[line_number - 1] = lines[line_number - 1].strip()[:-1] + " + " + modification + " ;\n"

    with open(target_file, 'w') as file:
        file.writelines(lines)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 add_lv.py <line_number> <lv_file> <target_file>")
    else:
        line_number = int(sys.argv[1])
        lv_file = sys.argv[2]
        target_file = sys.argv[3]
        modify_line(line_number, lv_file, target_file)