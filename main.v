// Etya Lichtman 327547998
// main module: translate each .vm file in a given folder to a folder contains Hack files
module main

import os

// Translates a single VM command to Hack assembly
fn translate_vm_command(cmd string, label_counter mut int) []string {
	mut lines := []string{}
	words := cmd.split(' ')
	match words[0] {
		'push' {
			if words.len == 3 && words[1] == 'constant' {
				value := words[2]
				lines << '@$value'
				lines << 'D=A'
				lines << '@SP'
				lines << 'A=M'
				lines << 'M=D'
				lines << '@SP'
				lines << 'M=M+1'
			}
		}
		'add' {
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << 'A=A-1'
			lines << 'M=M+D'
		}
		'sub' {
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << 'A=A-1'
			lines << 'M=M-D'
		}
		'and' {
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << 'A=A-1'
			lines << 'M=M&D'
		}
		'or' {
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << 'A=A-1'
			lines << 'M=M|D'
		}
		'neg' {
			lines << '@SP'
			lines << 'A=M-1'
			lines << 'M=-M'
		}
		'not' {
			lines << '@SP'
			lines << 'A=M-1'
			lines << 'M=!M'
		}
		'eq', 'gt', 'lt' {
			label_counter++
			label_id := label_counter.str()
			true_label := '${words[0].to_upper()}_TRUE_$label_id'
			end_label := '${words[0].to_upper()}_END_$label_id'
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << 'A=A-1'
			lines << 'D=M-D'
			lines << '@$true_label'
			match words[0] {
				'eq' { lines << 'D;JEQ' }
				'gt' { lines << 'D;JGT' }
				'lt' { lines << 'D;JLT' }
				else {}
			}
			lines << '@SP'
			lines << 'A=M-1'
			lines << 'M=0'
			lines << '@$end_label'
			lines << '0;JMP'
			lines << '($true_label)'
			lines << '@SP'
			lines << 'A=M-1'
			lines << 'M=-1'
			lines << '($end_label)'
		}
		else {}
	}
	return lines
}

/*
params:
input path - name of a .vm file
output path - same base, but end with .asm
*/
fn translate_vm_file(input_path string, output_path string) ! {
	// the ! means this function can retun an error
	mut label_counter := 0
	src := os.read_lines(input_path)!
	mut translated := []string{}
	for line in src {
		clean := line.all_before('//').trim_space()
		if clean.len == 0 {
			// line is a comment
			continue
		}
		translated << translate_vm_command(clean, mut label_counter)
	}
	os.write_file(output_path, translated.join('\n'))!  // the ! means this call can return an error
}

fn main() {
	if os.args.len != 2 {
		eprintln('Usage: vm_translator <input_folder>')
		return
	}
	input_folder := os.args[1]
	files := os.ls(input_folder)!
	output_folder := input_folder + '_asm'
	os.mkdir_all(output_folder) or {} //Try to create the directory output_folder (and any parent directories if needed), and if that fails, do nothing.
	for file in files {
		if file.ends_with('.vm') {
			input_path := os.join_path(input_folder, file)
			base := file.all_before_last('.')
			output_path := os.join_path(output_folder, base + '.asm')
			translate_vm_file(input_path, output_path) or {
				eprintln('Failed to translate $file: $err')
			}
		}
	}
	println('Done!')
}

