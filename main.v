// Etya Lichtman 327547998
// main module: translate each .vm file in a given folder to a folder contains Hack files
module main

import os

/* 
Translates a single VM command to Hack assembly.
params:
cmd - a single VM command we want to translate
label_counter - initialized with zero, and used for label's numbering
filename - the base name of the file containes the command (without .vm) 
*/
fn translate_vm_command(cmd string, label_counter mut int, filename string) []string {
	mut lines := []string{}  // declares and initializes a mutable empty array of string
	words := cmd.split(' ')
	match words[0] {
		'push' {
			seg := words[1]
			index := words[2]
			match seg {
				'constant' {
					lines << '@$index'
					lines << 'D=A'
				}
				'local' {
					lines << '@$index'
					lines << 'D=A'
					lines << '@LCL'
					lines << 'A=M+D'
					lines << 'D=M'
				}
				'argument' {
					lines << '@$index'
					lines << 'D=A'
					lines << '@ARG'
					lines << 'A=M+D'
					lines << 'D=M'
				}
				'this' {
					lines << '@$index'
					lines << 'D=A'
					lines << '@THIS'
					lines << 'A=M+D'
					lines << 'D=M'
				}
				'that' {
					lines << '@$index'
					lines << 'D=A'
					lines << '@THAT'
					lines << 'A=M+D'
					lines << 'D=M'
				}
				'temp' {
					base := 5 + index.int()
					lines << '@$base'
					lines << 'D=M'
				}
				'pointer' {
					ptr := if index == '0' { 'THIS' } else { 'THAT' }
					lines << '@$ptr'
					lines << 'D=M'
				}
				'static' {
					lines << '@${filename}_$index'
					lines << 'D=M'
				}
				else {}
			}
			lines << '@SP'
			lines << 'A=M'
			lines << 'M=D'
			lines << '@SP'
			lines << 'M=M+1'
		}
		'pop' {
			seg := words[1]
			index := words[2]
			match seg {
				'local', 'argument', 'this', 'that' {
					// store target addr in R13
					base := match seg {
						'local' { 'LCL' }
						'argument' { 'ARG' }
						'this' { 'THIS' }
						else { 'THAT' }
					}
					lines << '@$index'
					lines << 'D=A'
					lines << '@$base'
					lines << 'D=M+D'
					lines << '@R13'
					lines << 'M=D'
					lines << '@SP'
					lines << 'AM=M-1'
					lines << 'D=M'
					lines << '@R13'
					lines << 'A=M'
					lines << 'M=D'
				}
				'temp' {
					addr := 5 + index.int()
					lines << '@SP'
					lines << 'AM=M-1'
					lines << 'D=M'
					lines << '@$addr'
					lines << 'M=D'
				}
				'pointer' {
					ptr := if index == '0' { 'THIS' } else { 'THAT' }
					lines << '@SP'
					lines << 'AM=M-1'
					lines << 'D=M'
					lines << '@$ptr'
					lines << 'M=D'
				}
				'static' {
					lines << '@SP'
					lines << 'AM=M-1'
					lines << 'D=M'
					lines << '@${filename}_$index'
					lines << 'M=D'
				}
				else {}
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
			print(label_counter)
			true_label := '${words[0].to_upper()}_TRUE$label_counter'
			end_label := '${words[0].to_upper()}_END$label_counter'
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
			label_counter++
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
fn translate_vm_file(input_path string, output_path string, base string) ! {
	// the ! means this function can retun an error
	mut label_counter := 0
	src := os.read_lines(input_path)!
	// mut translated := []string{}
	mut translated := ['@256', 'D=A', '@SP', 'M=D']
	for line in src {
		clean := line.all_before('//').trim_space()
		if clean.len == 0 {
			// line is a comment
			continue
		}
		translated << translate_vm_command(clean, mut label_counter, base)
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
	os.mkdir_all(output_folder) or {} // Try to create the directory output_folder (and any parent directories if needed), and if that fails, do nothing.
	for file in files {
		if file.ends_with('.vm') {
			input_path := os.join_path(input_folder, file)
			base := file.all_before_last('.')
			output_path := os.join_path(output_folder, base + '.asm')
			translate_vm_file(input_path, output_path, base) or {
				eprintln('\x1b[31mFailed to translate $file: $err\x1b[0m')
			}
		}
	}
	println('\x1b[32m✔ Done!\x1b[0m')
}

