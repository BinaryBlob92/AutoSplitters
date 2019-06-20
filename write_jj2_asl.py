#!/usr/bin/env python3

import argparse
import pathlib
import pefile
import re
import sys

PROCESS_NAME = 'Jazz2'
ASL_INDENT = '    '

def main():
	ap = argparse.ArgumentParser(description='Create a Jazz Jackrabbit 2 '
		'ASL autosplitter for the provided game executables')
	ap.add_argument('exe_dir', nargs='?', default='.', type=pathlib.Path,
		help='the directory to search for Jazz Jackrabbit 2 exe files')
	ap.add_argument('--asl', default=sys.stdout, type=argparse.FileType('w'),
		help='write ASL script to this file rather than to stdout')
	ap.add_argument('-r', '--recursive', action='store_true',
		help='search for exe files recursively')
	args = ap.parse_args()

	write_jj2_asl(**vars(args))

def write_jj2_asl(exe_dir, asl, recursive):
	# Search for Jazz Jackrabbit 2 exe files and analyze them
	versions = {}
	for exe_file in exe_dir.glob(('**/' if recursive else '') + '*.exe'):
		try:
			version = GameVersion(exe_file)
		except RuntimeError as err:
			print(f'{exe_file}: {err}', file=sys.stderr)
			continue
		versions[version.tmstmp] = version

	# Create ASL file
	versions = tuple(versions[tmstmp] for tmstmp in sorted(versions))
	AslWriter(versions).write(asl)

class GameVersion:
	def __init__(self, exe_path):
		self.pe = pefile.PE(exe_path)
		self.exe = self.pe.__data__
		self.tmstmp = self.pe.FILE_HEADER.TimeDateStamp
		self.tmstmp_pos = \
			self.pe.FILE_HEADER.get_field_absolute_offset('TimeDateStamp')
		self.name = self.detect_version()
		self.addrs = self.find_addrs()

	def detect_version(self):
		matches = re.findall(
			br'\[Levelname\[\.j2l\]\]\0.*?'
			br'([^\0]+)\0+([^\0]*Jazz Jackrabbit 2[^\0]*)\0',
			self.exe
		)
		if len(matches) != 1:
			raise RuntimeError('Version detection failed')

		ver, name = matches[0]
		append_sw = \
			self.exe.find(b'shareware') != -1 and b'Shareware' not in name
		return b' '.join(s for s in (
			b'v' + ver.strip(),
			name.lstrip(b'Jazz Jackrabbit 2').strip(),
			b'Shareware' if append_sw else b'',
			b'(LK Avalon)' if self.exe.find(b'avalon') != -1 else b''
		) if s).decode('ascii')

	def find_addrs(self):
		return {
			'int menuItem': self.find_addr(
				br'\xC7\x05....\x01\x00\x00\x00' # mov <m32>, 1
				br'\xA3(....)'                   # mov menuItem, eax
				br'\xA3....'                     # mov <moffs32>, eax
			)[0],
			'int fullScreenImg': self.find_addr(
				br'\xBF....'                     # mov edi, <imm32>
				br'\xA3(....)'                   # mov fullScreenImg, eax
				br'\x83\xC4\x08'                 # add esp, 8
			)[0],
			'int demo': self.find_addr(
				br'\x8B\xC6'                     # mov eax, esi
				br'\x8B\x0D(....)'               # mov ecx, demo
				br'\x85\xC9'                     # test ecx, ecx
			)[0],
			'int inGame': self.find_addr(
				br'\xC7\x05....\x05\x00\x00\x00' # mov <m32>, 5
				br'\x89\x35(....)'               # mov inGame, esi
				br'\xE8....'                     # call <rel32>
			)[0],
			'int levelFinished': self.find_addr(
				br'\x7E\x42'                     # jle <rel8>
				br'\xA1(....)'                   # mov eax, levelFinished
				br'\x85\xC0'                     # test eax, eax
			)[0],
			'int levelEndTimer': self.find_addr(
				br'\xA3....'                     # mov levelFinished, eax
				br'\xA3(....)'                   # mov eax, levelFinished
				br'\x8B\x75\x24'                 # mov esi, [ebp+24h]
			)[0]
		}

	def find_addr(self, pattern):
		matches = re.findall(pattern, self.exe)
		if len(matches) == 0:
			raise RuntimeError('No matches found')
		if len(matches) > 1:
			raise RuntimeError('Multiple matches found')
		match = (matches[0],) if type(matches[0]) is bytes else matches[0]

		return tuple(self.va2rva(int.from_bytes(m, byteorder='little'))
			for m in match)

	def va2rva(self, va):
		return va - self.pe.OPTIONAL_HEADER.ImageBase

class AslWriter:
	def __init__(self, versions):
		self.versions = versions

	def write(self, out):
		out.write('\n'.join(self.create_state_descriptors() + (
			self.create_init_action(),
			self.create_update_action(),
			self.create_start_action(),
			self.create_isLoading_action(),
			self.create_split_action()
		)).replace('\t', ASL_INDENT))

	def create_state_descriptors(self):
		return tuple(self.create_state_descriptor(ver)
			for ver in self.versions)

	def create_state_descriptor(self, ver):
		max_name_len = max(len(name) for name in ver.addrs.keys())
		return f'''\
state("{PROCESS_NAME}", "{ver.name}") {{
''' + \
'\n'.join(
	f'\t{name: <{max_name_len}} : 0x{addr:06X};'
	for name, addr in ver.addrs.items()
) + f'''
}}
'''

	def create_init_action(self):
		return '''\
init {
	var versions = new dynamic[,]
	{
''' + \
',\n'.join(
	f'\t\t{{ 0x{ver.tmstmp:08X}, 0x{ver.tmstmp_pos:03X}, "{ver.name}" }}'
	for ver in self.versions
) + '''
	};
	var baseAddr = modules.First().BaseAddress;
	for (int i = 0; i < versions.GetLength(0); ++i)
	{
		var timestamp = versions[i, 0];
		IntPtr posTimestamp = baseAddr + versions[i, 1];
		var name = versions[i, 2];
		if (memory.ReadValue<int>(posTimestamp) == timestamp)
		{
			version = name;
			break;
		}
	}
}
'''

	@staticmethod
	def create_update_action():
		return '''\
update {
	return version != "";
}
'''

	@staticmethod
	def create_start_action():
		return '''\
start {
	return current.menuItem == 0 && current.demo == 0 && current.inGame > old.inGame;
}
'''

	@staticmethod
	def create_isLoading_action():
		return '''\
isLoading {
	return current.fullScreenImg != 0 && current.inGame != 0;
}
'''

	@staticmethod
	def create_split_action():
		return '''\
split {
    if(current.levelFinished == 1)
        return current.levelEndTimer >= 32828 && old.levelEndTimer < 32828;
    else if(current.levelFinished == 2)
        return current.levelEndTimer >= 32780 && old.levelEndTimer < 32780;
    else
        return false;
}
'''

if __name__ == '__main__':
	main()
