#! /usr/bin/env python3

import sys
import argparse
import winrm
import clipboard as c

from getpass import getpass


def load_script(scriptfile):
    print(f'Loading script from  {scriptfile}')


def run_winrm(endpoint,user,password,task):

    remotehost = f"http://{endpoint}:5985/wsman"

    print(f"Remote host {remotehost}")
    print(f"Connecting as User {user}")

    powershell_session = winrm.Session(remotehost,auth=(user,password), transport='ntlm')

    # force protocol to accept unsigned certs

    p = winrm.Protocol(
        endpoint=remotehost,
        transport='ntlm',           
        username=user,
        password=password,
        server_cert_validation='ignore')

    powershell_session.protocol = p

    try:
        run_ps = powershell_session.run_ps(task)
    except Exception as err:
        print(f"winRm Exception {err}")
        sys.exit(1)

    exit_code = run_ps.status_code
    print(f"Powershell exit code {exit_code}")
    error_value = run_ps.std_err
    output = run_ps.std_out
    error_value = error_value.decode('utf-8')
    output = output.decode('utf-8')

    if exit_code != 0:
        raise Exception('An error occurred in the PowerShell script, see logging for more info')
    print(len(output))
    return output


# when run from Command like get the args
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run a Powershell command or scriptblock on a remote server')
    parser.add_argument('--endpoint','-e', required=True, help='the remote server') 
    parser.add_argument('--user', '-u', required=True, help='the Remote username')
    parser.add_argument('--password', '-p',required=False, help='The password - will prompt if ommitted')
    parser.add_argument('--task', '-t', required=False, help='The powershell tasks  to execute in a single session')
    parser.add_argument('--version', '-v', action='version', version='%(prog)s verison 1.0')
    parser.add_argument('--script', '-s', help='The name of the script file to execute')
    parser.add_argument('--paste', action='store_true',  help='Paste a script snippet from the clipboard')

    args = parser.parse_args()
    if not args.password:
        args.password=getpass()

    if args.script:
        print(f'Executing Script file {args.script}')
    elif args.paste:
        txt = c.paste()
        print(f'Executing scripts from Clipboard\n {txt}')
    elif args.task:
        print(f'Exeuting task {args.task}')
    else:
        #  Read in the tasks
        taskset  = []
        print('Enter the Powershell commands. Enter quit when done.\n')
        while True:
            t = sys.stdin.readline().rstrip('\n')
            if t == 'quit':
                break
            else:
                taskset.append(t)
    print(taskset)
    
    output = run_winrm(args.endpoint,args.user,args.password,'\n'.join(taskset))
    print(output)
