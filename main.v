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
current_function - the name of the current function (used for scoping labels)
call_counter - used to generate unique return addresses
*/
fn translate_vm_command(cmd string, label_counter mut int, filename string, current_function mut string, call_counter mut int) []string {
	mut lines := []string{}  // declares and initializes a mutable empty array of string
	words := cmd.split(' ')
	pure_filename := os.base(filename)
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
					lines << '@${pure_filename}_$index'
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
					lines << '@${pure_filename}_$index'
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
		'label' {
			if words.len == 2 {
				lines << '(${pure_filename}$${words[1]})'.replace('$$', '$')
			}
		}
		'goto' {
			if words.len == 2 {
				lines << '@${pure_filename}$${words[1]}'.replace('$$', '$')
				lines << '0;JMP'
			}
		}
		'if-goto' {
			if words.len == 2 {
				lines << '@SP'
				lines << 'AM=M-1'
				lines << 'D=M'
				lines << '@${pure_filename}$${words[1]}'.replace('$$', '$')
				lines << 'D;JNE'
			}
		}
		'function' {
			if words.len == 3 {
				current_function = words[1]
				lines << '(${current_function})'
				n_locals := words[2].int()
				for _ in 0 .. n_locals {
					lines << '@0'
					lines << 'D=A'
					lines << '@SP'
					lines << 'A=M'
					lines << 'M=D'
					lines << '@SP'
					lines << 'M=M+1'
				}
			}
		}
		'call' {
			if words.len == 3 {
				ret_label := '${current_function}ret.${call_counter}'
				call_counter++
				lines << '@$ret_label'
				lines << 'D=A'
				lines << '@SP'
				lines << 'A=M'
				lines << 'M=D'
				lines << '@SP'
				lines << 'M=M+1'
				for seg in ['LCL', 'ARG', 'THIS', 'THAT'] {
					lines << '@$seg'
					lines << 'D=M'
					lines << '@SP'
					lines << 'A=M'
					lines << 'M=D'
					lines << '@SP'
					lines << 'M=M+1'
				}
				lines << '@SP'
				lines << 'D=M'
				lines << '@${5 + words[2].int()}'
				lines << 'D=D-A'
				lines << '@ARG'
				lines << 'M=D'
				lines << '@SP'
				lines << 'D=M'
				lines << '@LCL'
				lines << 'M=D'
				lines << '@${words[1]}'
				lines << '0;JMP'
				lines << '($ret_label)'
			}
		}
		'return' {
			lines << '@LCL'
			lines << 'D=M'
			lines << '@R13'
			lines << 'M=D'
			lines << '@5'
			lines << 'A=D-A'
			lines << 'D=M'
			lines << '@R14'
			lines << 'M=D'
			lines << '@SP'
			lines << 'AM=M-1'
			lines << 'D=M'
			lines << '@ARG'
			lines << 'A=M'
			lines << 'M=D'
			lines << '@ARG'
			lines << 'D=M+1'
			lines << '@SP'
			lines << 'M=D'
			for seg in ['THAT', 'THIS', 'ARG', 'LCL'] {
				lines << '@R13'
				lines << 'AM=M-1'
				lines << 'D=M'
				lines << '@$seg'
				lines << 'M=D'
			}
			lines << '@R14'
			lines << 'A=M'
			lines << '0;JMP'
		}
		else {}
	}
	return lines
}


/*
params:
input folder - name of a folder containing .vm file (or just a vm file)
output path - same base, but end with .asm
*/
fn translate_vm_files(input_folder string, output_path string) ! {
	// the ! means this function can retun an error
	mut label_counter := 0
	mut call_counter := 0
	mut current_function := ''
	// mut translated := []string{}
	mut translated := ['@256', 'D=A', '@SP', 'M=D']
	if os.is_dir(input_folder) {
		files := os.ls(input_folder)!
		for file in files {
			if file.ends_with('.vm') {
				input_path := os.join_path(input_folder, file)
				base := file.all_before_last('.')
				src := os.read_lines(input_path)!
				for line in src {
					clean := line.all_before('//').trim_space()
					if clean.len == 0 {
						// line is a comment
						continue
					}
					translated << translate_vm_command(clean, mut label_counter, base, mut current_function, mut call_counter)
				}
			}
		}
	}
	else {
		if input_folder.ends_with('.vm') {
				base := input_folder.all_before_last('.')
				src := os.read_lines(input_folder)!
				for line in src {
					clean := line.all_before('//').trim_space()
					if clean.len == 0 {
						// line is a comment
						continue
					}
					translated << translate_vm_command(clean, mut label_counter, base, mut current_function, mut call_counter)
				}
			}	
	}
	os.write_file(output_path, translated.join('\n'))!  // the ! means this call can return an error
}


fn main() {
	// if os.args.len != 2 && os.args.len !=0 {
	// 	eprintln('Usage: vm_translator <input_folder>')
	// 	return
	// }
	input_folder := if os.args.len == 2 {
			os.args[1]
		} else {
			if os.args.len == 0 {
				os.getwd()
			}
			else {
				eprintln('Usage: vm_translator <input_folder>')
				return
			}
		}
	output_path := if os.is_dir(input_folder) {
		 os.join_path(input_folder, os.base(input_folder) + '.asm')
	} else {
		os.join_path(input_folder.all_before_last('.') + '.asm')
	}
	translate_vm_files(input_folder, output_path) or {
				eprintln('\x1b[31mFailed to translate $input_folder: $err\x1b[0m')
			}
	println('\x1b[32m✔ Done!\x1b[0m')
}

