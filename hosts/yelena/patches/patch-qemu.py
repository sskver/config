#!/usr/bin/env python3
'''
epic script to hack QEMU source code
qemu? more like asus...

made it cuz the chinese fella who posted the qemu patch on github
isnt updating it quickly enough, so i made this script to do it instead
this script will:
- replace all vendor IDs with random ones
- replace all device strings that begin with "QEMU " with "ASUS "
- replace all device strings that are "QEMUQEMUQEMUQEMU" with "ASUSASUSASUSASUS"
- generate a patch file for the modifications
'''
import os
import re
import random
import argparse
import difflib

# Files that should be patched for EDK2/OVMF firmware modifications
EDK2_FILES = [
    'MdeModulePkg/MdeModulePkg.dec',
    'OvmfPkg/Bhyve/AcpiTables/Dsdt.asl',
    'OvmfPkg/Bhyve/AcpiTables/Facp.aslc',
    'OvmfPkg/Bhyve/AcpiTables/Hpet.aslc',
    'OvmfPkg/Bhyve/AcpiTables/Madt.aslc',
    'OvmfPkg/Bhyve/AcpiTables/Mcfg.aslc',
    'OvmfPkg/Bhyve/AcpiTables/Platform.h',
    'OvmfPkg/Bhyve/AcpiTables/Spcr.aslc',
    'OvmfPkg/Bhyve/BhyveRfbDxe/VbeShim.c',
    'OvmfPkg/Bhyve/BhyveX64.dsc',
    'OvmfPkg/Bhyve/SmbiosPlatformDxe/SmbiosPlatformDxe.c',
    'OvmfPkg/Include/IndustryStandard/Q35MchIch9.h',
    'OvmfPkg/Include/IndustryStandard/QemuPciBridgeCapabilities.h',
    'OvmfPkg/Library/QemuBootOrderLib/QemuBootOrderLib.c',
    'OvmfPkg/QemuVideoDxe/Driver.c',
    'OvmfPkg/SmbiosPlatformDxe/SmbiosPlatformDxe.c',
    'ShellPkg/ShellPkg.dec',
    'UefiCpuPkg/Library/CpuExceptionHandlerLib/X64/ExceptionHandlerAsm.nasm',
    'SecurityPkg/Library/AuthVariableLib/AuthServiceInternal.h',
]

def process_file(filepath, replace_vendor_id=False, apply_changes=True, patch_edk2=False, apply_qemu_strings=False):
    """process a single file and apply modifications or return a diff patch."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            original_content = f.read()
    except Exception as e:
        print(f"error reading {filepath}: {e}")
        return None

    # detect original line ending style
    has_crlf = '\r\n' in original_content
    has_cr = '\r' in original_content and not has_crlf
    
    # normalize line endings to Unix style for processing
    original_content_normalized = original_content.replace('\r\n', '\n').replace('\r', '\n')
    new_content = original_content_normalized
    
    patch_type = []  # Track which patches were applied

    # EDK2/OVMF firmware patches
    if patch_edk2:
        edk2_original = new_content
        # Replace firmware vendor strings
        new_content = re.sub(r'L"EDK II"', r'L"Intel Corporation"', new_content)
        new_content = re.sub(r'L"BHYVE"', r'L"INTEL "', new_content)
        new_content = re.sub(r'"EFI Development Kit II / OVMF\\0"', r'"Intel Corporation\\0"', new_content)
        new_content = re.sub(r'L"EDK II"', r'L"Intel Corporation"', new_content)
        
        # Replace ACPI OEM IDs and Table IDs
        new_content = re.sub(r"'B','H','Y','V','E',' '", r"'I','N','T','E','L',' '", new_content)
        new_content = re.sub(r"SIGNATURE_32\('B','H','Y','V'\)", r"SIGNATURE_32('I','N','T','L')", new_content)
        new_content = re.sub(r"SIGNATURE_64\('B','V','[^']+','[^']+','[^']+','[^']+','[^']*','[^']*'\)", 
                           r"SIGNATURE_64('U',' ','R','v','p',' ',' ',' ')", new_content)
        new_content = re.sub(r'0x20202020324B4445', r'0x2020207076525F55', new_content)
        
        '''        
        # Replace PCI vendor IDs in code
        new_content = re.sub(r'\b0x1234\b', r'0x8086', new_content)  # QEMU VGA vendor
        new_content = re.sub(r'\b0x1b36\b', r'0x8086', new_content)  # Red Hat vendor
        new_content = re.sub(r'\b0x1af4\b', r'0x8086', new_content)  # VirtIO vendor
        new_content = re.sub(r'\b0x15ad\b', r'0x8086', new_content)  # VMware vendor
        new_content = re.sub(r'\b0x10cc\b', r'0x1043', new_content)  # Articia vendor
        

        # Replace device IDs
        new_content = re.sub(r'\b0x29C0\b', r'0x4641', new_content)  # Q35 MCH device ID
        new_content = re.sub(r'\b0x1050\b', r'0x0416', new_content)  # VirtIO VGA device ID
        '''
        
        # Replace VESA signature
        new_content = re.sub(r'"VESA"', r'"VUSA"', new_content)
        new_content = re.sub(r'"FBSD"', r'"UEFI"', new_content)
        
        # Replace ACPI DefinitionBlock names
        new_content = re.sub(r'"DSDT", 2, "BHYVE", "BVDSDT"', r'"DSDT", 2, "INTEL ", "U Rvp   "', new_content)
        
        # Replace BIOS characteristics
        new_content = re.sub(r'0x1C // SystemReserved = VirtualMachineSupported', 
                           r'0x0D // SystemReserved = Hex2Binary = 0b00001101', new_content)
        
        # Replace variable names
        new_content = re.sub(r'L"VMMBootOrder', r'L"BootOrder', new_content)
        new_content = re.sub(r'L"certdb"', r'L"dbcert"', new_content)
        new_content = re.sub(r'L"certdbv"', r'L"dbvcert"', new_content)
        
        # Replace Shell supplier
        new_content = re.sub(r'L"EDK II"\|VOID\*', r'L"Intel Corporation"|VOID*', new_content)
        
        # Replace NASM push instructions for exception handling
        #new_content = re.sub(r'push\s+strict\s+dword\s+', r'push    strict qword ', new_content)
        
        if new_content != edk2_original:
            patch_type.append("EDK2")

    # replace vendor IDs with ASUS vendor ID (0x1043) if enabled
    if replace_vendor_id:
        qemu_original = new_content
        vendor_pattern = re.compile(r'(\bvendor_id\s*=\s*0x)([0-9a-fA-F]{1,4})\b')
        def vendor_repl(match):
            prefix = match.group(1)
            asus_vendor_id = "1043"
            return prefix + asus_vendor_id
        new_content = vendor_pattern.sub(vendor_repl, new_content)
        if new_content != qemu_original:
            patch_type.append("QEMU-VendorID")

    # replace device strings that begin with "QEMU " (only if enabled)
    if apply_qemu_strings:
        qemu_strings_original = new_content
        string_pattern = re.compile(r'(")QEMU( [^"]*")')
        def string_repl(match):
            return f'{match.group(1)}ASUS{match.group(2)}'
        new_content = string_pattern.sub(string_repl, new_content)

        # replace device strings that are "QEMUQEMUQEMUQEMU"
        string_pattern2 = re.compile(r'(")QEMUQEMUQEMUQEMU([^"]*")')
        def string_repl2(match):
            return f'{match.group(1)}ASUSASUSASUSASUS{match.group(2)}'
        new_content = string_pattern2.sub(string_repl2, new_content)

        # replace " Virtual " with " Real " in device strings (only within single-line string literals)
        virtual_pattern = re.compile(r'"([^"\n]*) Virtual ([^"\n]*)"')
        def virtual_repl(match):
            return f'"{match.group(1)} Real {match.group(2)}"'
        new_content = virtual_pattern.sub(virtual_repl, new_content)

        # remove " Virtio " from device strings (only within single-line string literals)
        virtio_pattern = re.compile(r'"([^"\n]*) Virtio ([^"\n]*)"')
        def virtio_repl(match):
            return f'"{match.group(1)} {match.group(2)}"'
        new_content = virtio_pattern.sub(virtio_repl, new_content)
        
        if new_content != qemu_strings_original:
            patch_type.append("QEMU-Strings")

    # check if there are changes
    if new_content != original_content_normalized:
        if apply_changes:
            # restore original line ending style
            if has_crlf:
                new_content = new_content.replace('\n', '\r\n')
            elif has_cr:
                new_content = new_content.replace('\n', '\r')
            
            # write changes directly to file
            try:
                with open(filepath, 'w', encoding='utf-8', newline='') as f:
                    f.write(new_content)
                patch_types_str = " + ".join(patch_type) if patch_type else "Unknown"
                print(f"[{patch_types_str}] {filepath}")
                return True
            except Exception as e:
                print(f"error writing {filepath}: {e}")
                return None
        else:
            # generate unified diff
            original_lines = original_content_normalized.splitlines(keepends=True)
            new_lines = new_content.splitlines(keepends=True)
            diff = difflib.unified_diff(
                original_lines, new_lines,
                fromfile=filepath, tofile=filepath,
                lineterm='\n'
            )
            return ''.join(diff)
    return None

def process_directory(directory, replace_vendor_id=False, apply_changes=True, patch_edk2=False, apply_qemu_strings=False):
    patch_chunks = []
    modified_count = 0
    
    # If patch_edk2 is enabled, only process specific EDK2 files
    if patch_edk2:
        for relative_path in EDK2_FILES:
            filepath = os.path.join(directory, relative_path)
            if os.path.exists(filepath):
                result = process_file(filepath, replace_vendor_id, apply_changes, patch_edk2, apply_qemu_strings)
                if result:
                    if apply_changes:
                        modified_count += 1
                    else:
                        patch_chunks.append(result)
            else:
                print(f"Warning: EDK2 file not found: {filepath}")
    else:
        # walk recursively through the directory, processing relevant source files.
        for root, _, files in os.walk(directory):
            for file in files:
                if file.endswith(('.c', '.h', '.cpp', '.cc', '.asl', '.aslc', '.dsc', '.dec', '.nasm')):
                    filepath = os.path.join(root, file)
                    result = process_file(filepath, replace_vendor_id, apply_changes, patch_edk2, apply_qemu_strings)
                    if result:
                        if apply_changes:
                            modified_count += 1
                        else:
                            patch_chunks.append(result)
    return (modified_count, patch_chunks)

def main():
    parser = argparse.ArgumentParser(
        description="generate a patch file for QEMU source code modifications"
    )
    parser.add_argument(
        "directory",
        help="path to the QEMU source tree directory"
    )
    parser.add_argument(
        "-o", "--output",
        default="qemu_modifications.patch",
        help="output patch file name (default: qemu_modifications.patch)"
    )
    parser.add_argument(
        "--replace-vendor-id",
        action="store_true",
        help="replace vendor IDs with ASUS vendor ID (0x1043)"
    )
    parser.add_argument(
        "--patch-edk2",
        action="store_true",
        help="apply EDK2/OVMF firmware patches (Intel vendor IDs and branding)"
    )
    parser.add_argument(
        "--generate-patch",
        action="store_true",
        help="generate patch file instead of applying changes directly"
    )
    args = parser.parse_args()

    apply_changes = not args.generate_patch
    # Only apply QEMU string patches when no specific flags are set (default behavior)
    apply_qemu_strings = not args.patch_edk2 and not args.replace_vendor_id
    modified_count, patches = process_directory(args.directory, args.replace_vendor_id, apply_changes, args.patch_edk2, apply_qemu_strings)
    
    if apply_changes:
        if modified_count > 0:
            print(f"\n{'='*60}")
            print(f"Successfully modified {modified_count} files")
            if args.patch_edk2:
                print(f"EDK2/OVMF firmware patches applied")
            if args.replace_vendor_id:
                print(f"QEMU vendor ID patches applied")
            if apply_qemu_strings:
                print(f"QEMU string patches applied (QEMU -> ASUS, Virtual -> Real)")
            print(f"{'='*60}")
        else:
            print("no modifications were made")
    else:
        if patches:
            with open(args.output, 'w', encoding='utf-8') as patch_file:
                for chunk in patches:
                    patch_file.write(chunk)
                    patch_file.write("\n")
            print(f"patch file created: {args.output}")
        else:
            print("no modifications were made; no patch file created.")

if __name__ == "__main__":
    main()
