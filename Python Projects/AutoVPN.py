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
#Main Menu
#----------------

class App:
    def __init__(self, root):
#==========================================================================================================================================================================================
#GUI Canvas
#----------------

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

        firewall_address=tk.StringVar()
        firewall_username=tk.StringVar()
        firewall_password=tk.StringVar()
        team_number=tk.StringVar()
        kit_number=tk.StringVar()
        int_number=tk.StringVar()
        wan_address=tk.StringVar()
        peer_address=tk.StringVar()
        pre_shared_key=tk.StringVar()

#==========================================================================================================================================================================================
#GUI Labels
#----------------

        TitleLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=15)
        TitleLabel["font"] = ft
        TitleLabel["fg"] = "#333333"
        TitleLabel["justify"] = "center"
        TitleLabel["text"] = "Welcome to AutoVPN; for automatically deploying a VPN connection. "
        TitleLabel.place(x=20,y=10,width=560,height=70)

        PasswordLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        PasswordLabel["font"] = ft
        PasswordLabel["fg"] = "#333333"
        PasswordLabel["justify"] = "center"
        PasswordLabel["text"] = "Please enter your password below:"
        PasswordLabel.place(x=200,y=125,width=200,height=25)

        TeamNumberLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        TeamNumberLabel["font"] = ft
        TeamNumberLabel["fg"] = "#333333"
        TeamNumberLabel["justify"] = "center"
        TeamNumberLabel["text"] = "Team Number"
        TeamNumberLabel.place(x=50,y=175,width=200,height=25)

        KitNumberLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        KitNumberLabel["font"] = ft
        KitNumberLabel["fg"] = "#333333"
        KitNumberLabel["justify"] = "center"
        KitNumberLabel["text"] = "Kit Number"
        KitNumberLabel.place(x=350,y=175,width=200,height=25)

        WANInterfaceLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        WANInterfaceLabel["font"] = ft
        WANInterfaceLabel["fg"] = "#333333"
        WANInterfaceLabel["justify"] = "center"
        WANInterfaceLabel["text"] = "WAN Interface Number eg- 1/'X'"
        WANInterfaceLabel.place(x=50,y=225,width=200,height=25)

        PeerIPLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        PeerIPLabel["font"] = ft
        PeerIPLabel["fg"] = "#333333"
        PeerIPLabel["justify"] = "center"
        PeerIPLabel["text"] = "Peer IP Address"
        PeerIPLabel.place(x=50,y=275,width=200,height=25)

        WANIPLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        WANIPLabel["font"] = ft
        WANIPLabel["fg"] = "#333333"
        WANIPLabel["justify"] = "center"
        WANIPLabel["text"] = "WAN IP Address"
        WANIPLabel.place(x=350,y=225,width=200,height=25)

        PSKLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        PSKLabel["font"] = ft
        PSKLabel["fg"] = "#333333"
        PSKLabel["justify"] = "center"
        PSKLabel["text"] = "Pre-Shared Key"
        PSKLabel.place(x=350,y=275,width=200,height=25)

        FirewallAddressLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        FirewallAddressLabel["font"] = ft
        FirewallAddressLabel["fg"] = "#333333"
        FirewallAddressLabel["justify"] = "center"
        FirewallAddressLabel["text"] = "Firewall Address"
        FirewallAddressLabel.place(x=50,y=75,width=200,height=25)

        FirewallUsernameLabel=tk.Label(root)
        ft = tkFont.Font(family='Times',size=10)
        FirewallUsernameLabel["font"] = ft
        FirewallUsernameLabel["fg"] = "#333333"
        FirewallUsernameLabel["justify"] = "center"
        FirewallUsernameLabel["text"] = "Firewall Username"
        FirewallUsernameLabel.place(x=350,y=75,width=200,height=25)

#==========================================================================================================================================================================================
#GUI Entries
#----------------

        WANInterfaceEntry=tk.Entry(root, textvariable=int_number)
        WANInterfaceEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        WANInterfaceEntry["font"] = ft
        WANInterfaceEntry["fg"] = "#333333"
        WANInterfaceEntry["justify"] = "center"
        WANInterfaceEntry["text"] = "int_number"
        WANInterfaceEntry.place(x=20,y=250,width=260,height=25)

        TeamNumberEntry=tk.Entry(root, textvariable=team_number)
        TeamNumberEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        TeamNumberEntry["font"] = ft
        TeamNumberEntry["fg"] = "#333333"
        TeamNumberEntry["justify"] = "center"
        TeamNumberEntry["text"] = "team_number"
        TeamNumberEntry.place(x=20,y=200,width=260,height=25)

        PeerIPEntry=tk.Entry(root, textvariable=peer_address)
        PeerIPEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        PeerIPEntry["font"] = ft
        PeerIPEntry["fg"] = "#333333"
        PeerIPEntry["justify"] = "center"
        PeerIPEntry["text"] = "peer_address"
        PeerIPEntry.place(x=20,y=300,width=260,height=25)

        PSKEntry=tk.Entry(root, textvariable=pre_shared_key)
        PSKEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        PSKEntry["font"] = ft
        PSKEntry["fg"] = "#333333"
        PSKEntry["justify"] = "center"
        PSKEntry["text"] = "pre_shared_key"
        PSKEntry.place(x=320,y=300,width=260,height=25)

        WANIPEntry=tk.Entry(root, textvariable=wan_address)
        WANIPEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        WANIPEntry["font"] = ft
        WANIPEntry["fg"] = "#333333"
        WANIPEntry["justify"] = "center"
        WANIPEntry["text"] = "wan_address"
        WANIPEntry.place(x=320,y=250,width=260,height=25)

        KitNumberEntry=tk.Entry(root, textvariable=kit_number)
        KitNumberEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        KitNumberEntry["font"] = ft
        KitNumberEntry["fg"] = "#333333"
        KitNumberEntry["justify"] = "center"
        KitNumberEntry["text"] = "kit_number"
        KitNumberEntry.place(x=320,y=200,width=260,height=25)

        PasswordEntry=tk.Entry(root, textvariable=firewall_password)
        PasswordEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        PasswordEntry["font"] = ft
        PasswordEntry["fg"] = "#333333"
        PasswordEntry["justify"] = "center"
        PasswordEntry["text"] = "firewall_password"
        PasswordEntry.place(x=40,y=150,width=520,height=25)
        PasswordEntry["show"] = "*"

        FirewallAddressEntry=tk.Entry(root, textvariable=firewall_address)
        FirewallAddressEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        FirewallAddressEntry["font"] = ft
        FirewallAddressEntry["fg"] = "#333333"
        FirewallAddressEntry["justify"] = "center"
        FirewallAddressEntry["text"] = "firewall_address"
        FirewallAddressEntry.place(x=20,y=100,width=260,height=25)

        FirewallUsernameEntry=tk.Entry(root, textvariable=firewall_username)
        FirewallUsernameEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        FirewallUsernameEntry["font"] = ft
        FirewallUsernameEntry["fg"] = "#333333"
        FirewallUsernameEntry["justify"] = "center"
        FirewallUsernameEntry["text"] = "firewall_username"
        FirewallUsernameEntry.place(x=320,y=100,width=260,height=25)

#==========================================================================================================================================================================================
#GUI Buttons
#----------------

        OK_Button=tk.Button(root)
        OK_Button["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Times',size=10)
        OK_Button["font"] = ft
        OK_Button["fg"] = "#000000"
        OK_Button["justify"] = "center"
        OK_Button["text"] = "Ok"
        OK_Button.place(x=120,y=350,width=70,height=25)
        OK_Button["command"] = self.OK_ButtonAction

        CANCEL_Button=tk.Button(root)
        CANCEL_Button["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Times',size=10)
        CANCEL_Button["font"] = ft
        CANCEL_Button["fg"] = "#000000"
        CANCEL_Button["justify"] = "center"
        CANCEL_Button["text"] = "Cancel"
        CANCEL_Button.place(x=410,y=350,width=70,height=25)
        CANCEL_Button["command"] = self.CANCEL_ButtonAction

    def OK_ButtonAction(self):
        fw_addr=firewall_address.get(root)
        fw_user=firewall_username.get(root)
        fw_pass=firewall_password.get(root)
        team_num=team_number.get(root)
        kit_num=kit_number.get(root)
        int_num=int_number.get(root)
        wan_addr=wan_address.get(root)
        peer_addr=peer_address.get(root)
        psk_key=pre_shared_key.get(root)

        print("Firewall Address: " + fw_addr)
        print("Firewall Username: " + fw_user)
        print("Firewall Password: " + fw_pass)
        print("Team Number: " + team_num)
        print("Kit Number: " + kit_num)
        print("Interface Number: " + int_num)
        print("WAN Address: " + wan_addr)
        print("Peer Address: " + peer_addr)
        print("Pre-Shared Key: " + psk_key)
        #configure_firewall(firewall_address, firewall_username, firewall_password, team_number, kit_number, pre_shared_key, peer_address, int_number, wan_address)

    def CANCEL_ButtonAction(self):
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
