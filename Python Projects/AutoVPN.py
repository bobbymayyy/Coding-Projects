import sys
import tkinter as tk
import tkinter.font as tkFont
#import paramiko
#from getpass import getpass
#import time

#==========================================================================================================================================================================================
#Function Definitions
#----------------


def wait_for_prompt(channel, prompt=">"):
    while True:
        output = channel.recv(4096).decode()
        print(output)
        if re.search(f"{prompt}\\s*$", output):
            break


def configure_firewall(firewall_address, firewall_username, firewall_password, team_number, kit_number, pre_shared_key, peer_address, int_number, wan_address):
    # Create an SSH client with threading disabled
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        # Connect to the firewall
        ssh.connect(firewall_address, username=firewall_username, password=firewall_password, look_for_keys=False, allow_agent=False, timeout=5)

        # Get the SSH transport
        transport = ssh.get_transport()

        # Wait for 30 seconds before executing the "configure" command
        print("Logging in...")
        time.sleep(20)

        # Open an interactive shell
        shell = ssh.invoke_shell()

        # Send each command one by one
        commands = [
            "configure",
            f"set network interface tunnel units tunnel.{team_number} ip 192.168.{team_number}.2/24",
            f"set network interface tunnel units tunnel.{team_number} mtu 1350",
            f"set network virtual-router default interface tunnel.{team_number}",
            f"set zone VPN network layer3 tunnel.{team_number}",
            f"set network ike crypto-profiles ike-crypto-profiles CPT{team_number} hash sha384 dh-group group20 encryption aes-256-cbc lifetime seconds 28800",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_number} esp authentication sha256 encryption aes-256-cbc",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_number} lifetime seconds 3600",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_number} dh-group group20",
            f"set network ike gateway CPT{team_number} authentication pre-shared-key key {pre_shared_key}",
            f"set network ike gateway CPT{team_number} protocol ikev2 dpd enable yes",
            f"set network ike gateway CPT{team_number} protocol ikev2 ike-crypto-profile CPT{team_number}",
            f"set network ike gateway CPT{team_number} protocol version ikev2",
            f"set network ike gateway CPT{team_number} local-address interface ethernet1/{int_number} ip {wan_address}/28",
            f"set network ike gateway CPT{team_number} protocol-common nat-traversal enable no",
            f"set network ike gateway CPT{team_number} protocol-common fragmentation enable yes",
            f"set network ike gateway CPT{team_number} peer-address ip {peer_address}",
            f"set network ike gateway CPT{team_number} local-id id {team_number}cpt@cpb.army.mil type ufqdn",
            f"set network tunnel ipsec CPT{team_number} auto-key ike-gateway CPT{team_number}",
            f"set network tunnel ipsec CPT{team_number} auto-key ipsec-crypto-profile CPT{team_number}",
            f"set network tunnel ipsec CPT{team_number} tunnel-monitor enable no",
            f"set network tunnel ipsec CPT{team_number} tunnel-interface tunnel.{team_number}",
            f"set network tunnel ipsec CPT{team_number} anti-replay yes",
            f"set network tunnel ipsec CPT{team_number} copy-tos yes",
            f"set network tunnel ipsec CPT{team_number} disabled no",
            f"set network tunnel ipsec CPT{team_number} tunnel-monitor destination-ip 192.168.{team_number}.1 enable yes tunnel-monitor-profile default",
            f"set network virtual-router default protocol ospf enable yes",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} enable yes",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} passive no",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} gr-delay 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} metric 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} priority 1",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} hello-interval 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} dead-counts 4",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} retransmit-interval 5",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} transit-delay 1",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_number} interface tunnel.{team_number} link-type p2p",
            f"set network virtual-router default protocol ospf router-id {wan_address}",
            f"set network virtual-router default protocol redist-profile Kit{kit_number} action redist",
            f"set network virtual-router default protocol redist-profile Kit{kit_number} priority 1",
            f"set network virtual-router default protocol redist-profile Kit{kit_number} filter type connect destination 10.{kit_number}.0.0/16",
            f"set network virtual-router default protocol ospf export-rules Kit{kit_number} new-path-type ext-2",
            f"set network virtual-router default protocol ospf enable yes area 0.0.0.{team_number} type normal",
            "commit",
            "exit",
            "exit"
        ]

        for command in commands:
            print(f"Executing command: {command}")
            shell.send(command + "\n")
            time.sleep(3)  # Add a delay to allow the command to be processed

        # Wait for the command to finish (with a timeout)
        timeout = 30  # Set your desired timeout (in seconds)
        start_time = time.time()
        while not shell.recv_ready():
            time.sleep(1)  # Adjust sleep time if needed
            if time.time() - start_time > timeout:
                print("Timeout reached. Assuming command execution is complete.")
                break

        output = shell.recv(4096).decode()
        print(output)

    except paramiko.AuthenticationException:
        print("Authentication failed. Please check your credentials.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Close the SSH connection
        ssh.close()


#==========================================================================================================================================================================================
#Main Menu Definition
#----------------

class App:
    def __init__(self, root):
        firewall_address=tk.StringVar()
        firewall_username=tk.StringVar()
        firewall_password=tk.StringVar()
        team_number=tk.StringVar()
        kit_number=tk.StringVar()
        int_number=tk.StringVar()
        wan_address=tk.StringVar()
        peer_address=tk.StringVar()
        pre_shared_key=tk.StringVar()

        #setting title
        root.title("AutoVPN")
        #setting window size
        width=600
        height=400
        screenwidth = root.winfo_screenwidth()
        screenheight = root.winfo_screenheight()
        alignstr = '%dx%d+%d+%d' % (width, height, (screenwidth - width) / 2, (screenheight - height) / 2)
        root.geometry(alignstr)
        root.resizable(width=False, height=False)

        GLineEdit_358=tk.Entry(root)
        GLineEdit_358["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_358["font"] = ft
        GLineEdit_358["fg"] = "#333333"
        GLineEdit_358["justify"] = "center"
        GLineEdit_358["text"] = "int_number"
        GLineEdit_358.place(x=20,y=250,width=260,height=25)
        GLineEdit_358["textvariable"] = int_number

        GLineEdit_746=tk.Entry(root)
        GLineEdit_746["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_746["font"] = ft
        GLineEdit_746["fg"] = "#333333"
        GLineEdit_746["justify"] = "center"
        GLineEdit_746["text"] = "team_number"
        GLineEdit_746.place(x=20,y=200,width=260,height=25)
        GLineEdit_746["textvariable"] = team_number

        GLineEdit_265=tk.Entry(root)
        GLineEdit_265["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_265["font"] = ft
        GLineEdit_265["fg"] = "#333333"
        GLineEdit_265["justify"] = "center"
        GLineEdit_265["text"] = "peer_address"
        GLineEdit_265.place(x=20,y=300,width=260,height=25)
        GLineEdit_265["textvariable"] = peer_address

        GLineEdit_624=tk.Entry(root)
        GLineEdit_624["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_624["font"] = ft
        GLineEdit_624["fg"] = "#333333"
        GLineEdit_624["justify"] = "center"
        GLineEdit_624["text"] = "pre_shared_key"
        GLineEdit_624.place(x=320,y=300,width=260,height=25)
        GLineEdit_624["textvariable"] = pre_shared_key

        GLineEdit_331=tk.Entry(root)
        GLineEdit_331["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_331["font"] = ft
        GLineEdit_331["fg"] = "#333333"
        GLineEdit_331["justify"] = "center"
        GLineEdit_331["text"] = "wan_address"
        GLineEdit_331.place(x=320,y=250,width=260,height=25)
        GLineEdit_331["textvariable"] = wan_address

        GLineEdit_881=tk.Entry(root)
        GLineEdit_881["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_881["font"] = ft
        GLineEdit_881["fg"] = "#333333"
        GLineEdit_881["justify"] = "center"
        GLineEdit_881["text"] = "kit_number"
        GLineEdit_881.place(x=320,y=200,width=260,height=25)
        GLineEdit_881["textvariable"] = kit_number

        GButton_76=tk.Button(root)
        GButton_76["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Times',size=10)
        GButton_76["font"] = ft
        GButton_76["fg"] = "#000000"
        GButton_76["justify"] = "center"
        GButton_76["text"] = "Ok"
        GButton_76.place(x=120,y=350,width=70,height=25)
        GButton_76["command"] = self.GButton_76_command

        GButton_872=tk.Button(root)
        GButton_872["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Times',size=10)
        GButton_872["font"] = ft
        GButton_872["fg"] = "#000000"
        GButton_872["justify"] = "center"
        GButton_872["text"] = "Cancel"
        GButton_872.place(x=410,y=350,width=70,height=25)
        GButton_872["command"] = self.GButton_872_command

        GLineEdit_343=tk.Entry(root)
        GLineEdit_343["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_343["font"] = ft
        GLineEdit_343["fg"] = "#333333"
        GLineEdit_343["justify"] = "center"
        GLineEdit_343["text"] = "firewall_password"
        GLineEdit_343.place(x=40,y=150,width=520,height=25)
        GLineEdit_343["show"] = "*"
        GLineEdit_343["textvariable"] = firewall_password

        GLabel_513=tk.Label(root)
        ft = tkFont.Font(family='Times',size=15)
        GLabel_513["font"] = ft
        GLabel_513["fg"] = "#333333"
        GLabel_513["justify"] = "center"
        GLabel_513["text"] = "Welcome to AutoVPN; for automatically deploying a VPN connection. "
        GLabel_513.place(x=20,y=10,width=560,height=70)

        GLabel_813=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_813["font"] = ft
        GLabel_813["fg"] = "#333333"
        GLabel_813["justify"] = "center"
        GLabel_813["text"] = "Please enter your password below:"
        GLabel_813.place(x=200,y=125,width=200,height=25)

        GLabel_927=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_927["font"] = ft
        GLabel_927["fg"] = "#333333"
        GLabel_927["justify"] = "center"
        GLabel_927["text"] = "Team Number"
        GLabel_927.place(x=50,y=175,width=200,height=25)

        GLabel_683=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_683["font"] = ft
        GLabel_683["fg"] = "#333333"
        GLabel_683["justify"] = "center"
        GLabel_683["text"] = "Kit Number"
        GLabel_683.place(x=350,y=175,width=200,height=25)

        GLabel_178=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_178["font"] = ft
        GLabel_178["fg"] = "#333333"
        GLabel_178["justify"] = "center"
        GLabel_178["text"] = "WAN Interface Number eg- 1/'X'"
        GLabel_178.place(x=50,y=225,width=200,height=25)

        GLabel_399=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_399["font"] = ft
        GLabel_399["fg"] = "#333333"
        GLabel_399["justify"] = "center"
        GLabel_399["text"] = "Peer IP Address"
        GLabel_399.place(x=50,y=275,width=200,height=25)

        GLabel_282=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_282["font"] = ft
        GLabel_282["fg"] = "#333333"
        GLabel_282["justify"] = "center"
        GLabel_282["text"] = "WAN IP Address"
        GLabel_282.place(x=350,y=225,width=200,height=25)

        GLabel_511=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_511["font"] = ft
        GLabel_511["fg"] = "#333333"
        GLabel_511["justify"] = "center"
        GLabel_511["text"] = "Pre-Shared Key"
        GLabel_511.place(x=350,y=275,width=200,height=25)

        GLineEdit_551=tk.Entry(root)
        GLineEdit_551["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_551["font"] = ft
        GLineEdit_551["fg"] = "#333333"
        GLineEdit_551["justify"] = "center"
        GLineEdit_551["text"] = "firewall_address"
        GLineEdit_551.place(x=20,y=100,width=260,height=25)
        GLineEdit_551["textvariable"] = firewall_address

        GLineEdit_26=tk.Entry(root)
        GLineEdit_26["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_26["font"] = ft
        GLineEdit_26["fg"] = "#333333"
        GLineEdit_26["justify"] = "center"
        GLineEdit_26["text"] = "firewall_username"
        GLineEdit_26.place(x=320,y=100,width=260,height=25)
        GLineEdit_26["textvariable"] = firewall_username

        GLabel_774=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_774["font"] = ft
        GLabel_774["fg"] = "#333333"
        GLabel_774["justify"] = "center"
        GLabel_774["text"] = "Firewall Address"
        GLabel_774.place(x=50,y=75,width=200,height=25)

        GLabel_694=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        GLabel_694["font"] = ft
        GLabel_694["fg"] = "#333333"
        GLabel_694["justify"] = "center"
        GLabel_694["text"] = "Firewall Username"
        GLabel_694.place(x=350,y=75,width=200,height=25)

    def GButton_76_command(self):

        fw_addr=firewall_address.get()
        fw_user=firewall_username.get()
        fw_pass=firewall_password.get()
        team_num=team_number.get()
        kit_num=kit_number.get()
        int_num=int_number.get()
        wan_addr=wan_address.get()
        peer_addr=peer_address.get()
        psk_key=pre_shared_key.get()

        print(fw_addr)
        print(fw_user)
        print(fw_pass)
        print(team_num)
        print(kit_num)
        print(int_num)
        print(wan_addr)
        print(peer_addr)
        print(psk_key)
        #configure_firewall(firewall_address, firewall_username, firewall_password, team_number, kit_number, pre_shared_key, peer_address, int_number, wan_address)


    def GButton_872_command(self):
        sys.exit()


#==========================================================================================================================================================================================
#==========================================================================================================================================================================================
#==========================================================================================================================================================================================
#Main Flow
#----------------

if __name__ == "__main__":
    root = tk.Tk()
    app = App(root)
    root.mainloop()
