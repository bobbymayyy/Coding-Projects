import sys
import pexpect
import re
import tkinter as tk
import tkinter.font as tkFont
import paramiko
from getpass import getpass
import time

#==========================================================================================================================================================================================
#Function Definitions
#----------------

def deploy_firewall(fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr):
    try:
        # Create SSH connection
        ssh_newkey = 'Are you sure you want to continue connecting'
        ssh_cmd = f'ssh {fw_user}@{fw_addr}'
        ssh_conn = pexpect.spawn(ssh_cmd)

        # Handle SSH key verification
        i = ssh_conn.expect([ssh_newkey, 'password:', pexpect.EOF, pexpect.TIMEOUT])
        if i == 0:
            ssh_conn.sendline('yes')
            i = ssh_conn.expect([ssh_newkey, 'password:', pexpect.EOF, pexpect.TIMEOUT])
        
        # Enter password
        if i == 1:
            ssh_conn.sendline(fw_pass)
        elif i == 2 or i == 3:
            raise Exception('SSH connection failed')

        # Wait for prompt
        ssh_conn.expect_exact(prompt)
        
        # Send commands
        commands = [
            "configure",
            f"set network interface tunnel units tunnel.{team_num} ip 192.168.{team_num}.2/24",
            f"set network interface tunnel units tunnel.{team_num} mtu 1350",
            f"set network virtual-router default interface tunnel.{team_num}",
            f"set zone VPN network layer3 tunnel.{team_num}",
            f"set network ike crypto-profiles ike-crypto-profiles CPT{team_num} hash sha384 dh-group group20 encryption aes-256-cbc lifetime seconds 28800",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} esp authentication sha256 encryption aes-256-cbc",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} lifetime seconds 3600",
            f"set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} dh-group group20",
            f"set network ike gateway CPT{team_num} authentication pre-shared-key key {psk_key}",
            f"set network ike gateway CPT{team_num} protocol ikev2 dpd enable yes",
            f"set network ike gateway CPT{team_num} protocol ikev2 ike-crypto-profile CPT{team_num}",
            f"set network ike gateway CPT{team_num} protocol version ikev2",
            f"set network ike gateway CPT{team_num} local-address interface ethernet1/{int_num} ip {wan_addr}/28",
            f"set network ike gateway CPT{team_num} protocol-common nat-traversal enable no",
            f"set network ike gateway CPT{team_num} protocol-common fragmentation enable yes",
            f"set network ike gateway CPT{team_num} peer-address ip {peer_addr}",
            f"set network ike gateway CPT{team_num} local-id id {team_num}cpt@cpb.army.mil type ufqdn",
            f"set network tunnel ipsec CPT{team_num} auto-key ike-gateway CPT{team_num}",
            f"set network tunnel ipsec CPT{team_num} auto-key ipsec-crypto-profile CPT{team_num}",
            f"set network tunnel ipsec CPT{team_num} tunnel-monitor enable no",
            f"set network tunnel ipsec CPT{team_num} tunnel-interface tunnel.{team_num}",
            f"set network tunnel ipsec CPT{team_num} anti-replay yes",
            f"set network tunnel ipsec CPT{team_num} copy-tos yes",
            f"set network tunnel ipsec CPT{team_num} disabled no",
            f"set network tunnel ipsec CPT{team_num} tunnel-monitor destination-ip 192.168.{team_num}.1 enable yes tunnel-monitor-profile default",
            f"set network virtual-router default protocol ospf enable yes",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} enable yes",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} passive no",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} gr-delay 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} metric 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} priority 1",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} hello-interval 10",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} dead-counts 4",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} retransmit-interval 5",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} transit-delay 1",
            f"set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} link-type p2p",
            f"set network virtual-router default protocol ospf router-id {wan_addr}",
            f"set network virtual-router default protocol redist-profile Kit{kit_num} action redist",
            f"set network virtual-router default protocol redist-profile Kit{kit_num} priority 1",
            f"set network virtual-router default protocol redist-profile Kit{kit_num} filter type connect destination 10.{kit_num}.0.0/16",
            f"set network virtual-router default protocol ospf export-rules Kit{kit_num} new-path-type ext-2",
            f"set network virtual-router default protocol ospf enable yes area 0.0.0.{team_num} type normal",
            "commit",
            "exit",
            "exit"
        ]
        for command in commands:
            ssh_conn.sendline(command)
            ssh_conn.expect_exact(prompt)

        ssh_conn.close()
        print("Configuration completed successfully.")

    except Exception as e:
        print(f"Error: {e}")
        if ssh_conn:
            ssh_conn.close()

def destroy_firewall(fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr):
    try:
        # Create SSH connection
        ssh_newkey = 'Are you sure you want to continue connecting'
        ssh_cmd = f'ssh {fw_user}@{fw_addr}'
        ssh_conn = pexpect.spawn(ssh_cmd)

        # Handle SSH key verification
        i = ssh_conn.expect([ssh_newkey, 'password:', pexpect.EOF, pexpect.TIMEOUT])
        if i == 0:
            ssh_conn.sendline('yes')
            i = ssh_conn.expect([ssh_newkey, 'password:', pexpect.EOF, pexpect.TIMEOUT])
        
        # Enter password
        if i == 1:
            ssh_conn.sendline(fw_pass)
        elif i == 2 or i == 3:
            raise Exception('SSH connection failed')

        # Wait for prompt
        ssh_conn.expect_exact(prompt)
        
        # Send commands
        commands = [
            "configure",
            f"no set network interface tunnel units tunnel.{team_num} ip 192.168.{team_num}.2/24",
            f"no set network interface tunnel units tunnel.{team_num} mtu 1350",
            f"no set network virtual-router default interface tunnel.{team_num}",
            f"no set zone VPN network layer3 tunnel.{team_num}",
            f"no set network ike crypto-profiles ike-crypto-profiles CPT{team_num} hash sha384 dh-group group20 encryption aes-256-cbc lifetime seconds 28800",
            f"no set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} esp authentication sha256 encryption aes-256-cbc",
            f"no set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} lifetime seconds 3600",
            f"no set network ike crypto-profiles ipsec-crypto-profiles CPT{team_num} dh-group group20",
            f"no set network ike gateway CPT{team_num} authentication pre-shared-key key {psk_key}",
            f"no set network ike gateway CPT{team_num} protocol ikev2 dpd enable yes",
            f"no set network ike gateway CPT{team_num} protocol ikev2 ike-crypto-profile CPT{team_num}",
            f"no set network ike gateway CPT{team_num} protocol version ikev2",
            f"no set network ike gateway CPT{team_num} local-address interface ethernet1/{int_num} ip {wan_addr}/28",
            f"no set network ike gateway CPT{team_num} protocol-common nat-traversal enable no",
            f"no set network ike gateway CPT{team_num} protocol-common fragmentation enable yes",
            f"no set network ike gateway CPT{team_num} peer-address ip {peer_addr}",
            f"no set network ike gateway CPT{team_num} local-id id {team_num}cpt@cpb.army.mil type ufqdn",
            f"no set network tunnel ipsec CPT{team_num} auto-key ike-gateway CPT{team_num}",
            f"no set network tunnel ipsec CPT{team_num} auto-key ipsec-crypto-profile CPT{team_num}",
            f"no set network tunnel ipsec CPT{team_num} tunnel-monitor enable no",
            f"no set network tunnel ipsec CPT{team_num} tunnel-interface tunnel.{team_num}",
            f"no set network tunnel ipsec CPT{team_num} anti-replay yes",
            f"no set network tunnel ipsec CPT{team_num} copy-tos yes",
            f"no set network tunnel ipsec CPT{team_num} disabled no",
            f"no set network tunnel ipsec CPT{team_num} tunnel-monitor destination-ip 192.168.{team_num}.1 enable yes tunnel-monitor-profile default",
            f"no set network virtual-router default protocol ospf enable yes",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} enable yes",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} passive no",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} gr-delay 10",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} metric 10",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} priority 1",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} hello-interval 10",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} dead-counts 4",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} retransmit-interval 5",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} transit-delay 1",
            f"no set network virtual-router default protocol ospf area 0.0.0.{team_num} interface tunnel.{team_num} link-type p2p",
            f"no set network virtual-router default protocol ospf router-id {wan_addr}",
            f"no set network virtual-router default protocol redist-profile Kit{kit_num} action redist",
            f"no set network virtual-router default protocol redist-profile Kit{kit_num} priority 1",
            f"no set network virtual-router default protocol redist-profile Kit{kit_num} filter type connect destination 10.{kit_num}.0.0/16",
            f"no set network virtual-router default protocol ospf export-rules Kit{kit_num} new-path-type ext-2",
            f"no set network virtual-router default protocol ospf enable yes area 0.0.0.{team_num} type normal",
            "commit",
            "exit",
            "exit"
        ]
        for command in commands:
            ssh_conn.sendline(command)
            ssh_conn.expect_exact(prompt)

        ssh_conn.close()
        print("Configuration completed successfully.")

    except Exception as e:
        print(f"Error: {e}")
        if ssh_conn:
            ssh_conn.close()

#==========================================================================================================================================================================================
#Main Menu
#----------------

class App:
    def DoneEXIT_ButtonAction(DoneScreenWindow):
        sys.exit()

    def DEPLOY_ButtonAction(self):
        DoneScreenWindow=tk.Toplevel(root)

        #setting title
        DoneScreenWindow.title("AutoVPN")
        #setting window size
        width=295
        height=140
        DoneScreenWindow.configure(background='#393d49')
        screenwidth = DoneScreenWindow.winfo_screenwidth()
        screenheight = DoneScreenWindow.winfo_screenheight()
        alignstr = '%dx%d+%d+%d' % (width, height, (screenwidth - width) / 2, (screenheight - height) / 2)
        DoneScreenWindow.geometry(alignstr)
        DoneScreenWindow.resizable(width=False, height=False)
        DoneLabel=tk.Label(DoneScreenWindow)
        ft = tkFont.Font(family='Verdana',size=30)
        DoneLabel["font"] = ft
        DoneLabel["bg"] = "#393d49"
        DoneLabel["fg"] = "#ffffff"
        DoneLabel["justify"] = "center"
        DoneLabel["text"] = "Done."
        DoneLabel.place(x=15,y=10,width=270,height=80)

        DoneExitButton=tk.Button(DoneScreenWindow)
        DoneExitButton["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Verdana',size=10)
        DoneExitButton["font"] = ft
        DoneExitButton["bg"] = "#5a6074"
        DoneExitButton["fg"] = "#ffffff"
        DoneExitButton["justify"] = "center"
        DoneExitButton["text"] = "Exit"
        DoneExitButton.place(x=110,y=90,width=70,height=25)
        DoneExitButton["command"] = self.DoneEXIT_ButtonAction

        fw_addr=self.firewall_address.get()
        fw_user=self.firewall_username.get()
        fw_pass=self.firewall_password.get()
        team_num=self.team_number.get()
        kit_num=self.kit_number.get()
        int_num=self.int_number.get()
        wan_addr=self.wan_address.get()
        peer_addr=self.peer_address.get()
        psk_key=self.pre_shared_key.get()

#------>deploy_firewall(fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr)

    def DESTROY_ButtonAction(self):
        DoneScreenWindow=tk.Toplevel(root)

        #setting title
        DoneScreenWindow.title("AutoVPN")
        #setting window size
        width=295
        height=140
        DoneScreenWindow.configure(background='#393d49')
        screenwidth = DoneScreenWindow.winfo_screenwidth()
        screenheight = DoneScreenWindow.winfo_screenheight()
        alignstr = '%dx%d+%d+%d' % (width, height, (screenwidth - width) / 2, (screenheight - height) / 2)
        DoneScreenWindow.geometry(alignstr)
        DoneScreenWindow.resizable(width=False, height=False)
        DoneLabel=tk.Label(DoneScreenWindow)
        ft = tkFont.Font(family='Verdana',size=30)
        DoneLabel["font"] = ft
        DoneLabel["bg"] = "#393d49"
        DoneLabel["fg"] = "#ffffff"
        DoneLabel["justify"] = "center"
        DoneLabel["text"] = "Done."
        DoneLabel.place(x=15,y=10,width=270,height=80)

        DoneExitButton=tk.Button(DoneScreenWindow)
        DoneExitButton["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Verdana',size=10)
        DoneExitButton["font"] = ft
        DoneExitButton["bg"] = "#5a6074"
        DoneExitButton["fg"] = "#ffffff"
        DoneExitButton["justify"] = "center"
        DoneExitButton["text"] = "Exit"
        DoneExitButton.place(x=110,y=90,width=70,height=25)
        DoneExitButton["command"] = self.DoneEXIT_ButtonAction

        fw_addr=self.firewall_address.get()
        fw_user=self.firewall_username.get()
        fw_pass=self.firewall_password.get()
        team_num=self.team_number.get()
        kit_num=self.kit_number.get()
        int_num=self.int_number.get()
        wan_addr=self.wan_address.get()
        peer_addr=self.peer_address.get()
        psk_key=self.pre_shared_key.get()

#------>destroy_firewall(fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr)

    def __init__(self, root):
#==========================================================================================================================================================================================
#GUI Canvas
#----------------

        #setting title
        root.title("AutoVPN")
        
        #setting window size
        width=600
        height=400
        root.configure(background='#393d49')
        screenwidth = root.winfo_screenwidth()
        screenheight = root.winfo_screenheight()
        alignstr = '%dx%d+%d+%d' % (width, height, (screenwidth - width) / 2, (screenheight - height) / 2)
        root.geometry(alignstr)
        root.resizable(width=False, height=False)

#==========================================================================================================================================================================================
#GUI Labels
#----------------

        TitleLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=30)
        TitleLabel["font"] = ft
        TitleLabel["bg"] = "#393d49"
        TitleLabel["fg"] = "#ffffff"
        TitleLabel["justify"] = "center"
        TitleLabel["text"] = "Welcome to AutoVPN."
        TitleLabel.place(x=20,y=10,width=560,height=70)

        PasswordLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        PasswordLabel["font"] = ft
        PasswordLabel["bg"] = "#393d49"
        PasswordLabel["fg"] = "#ffffff"
        PasswordLabel["justify"] = "center"
        PasswordLabel["text"] = "Please enter your password below:"
        PasswordLabel.place(x=170,y=125,width=260,height=25)

        TeamNumberLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        TeamNumberLabel["font"] = ft
        TeamNumberLabel["bg"] = "#393d49"
        TeamNumberLabel["fg"] = "#ffffff"
        TeamNumberLabel["justify"] = "center"
        TeamNumberLabel["text"] = "Team Number"
        TeamNumberLabel.place(x=20,y=175,width=260,height=25)

        KitNumberLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        KitNumberLabel["font"] = ft
        KitNumberLabel["bg"] = "#393d49"
        KitNumberLabel["fg"] = "#ffffff"
        KitNumberLabel["justify"] = "center"
        KitNumberLabel["text"] = "Kit Number"
        KitNumberLabel.place(x=320,y=175,width=260,height=25)

        WANInterfaceLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        WANInterfaceLabel["font"] = ft
        WANInterfaceLabel["bg"] = "#393d49"
        WANInterfaceLabel["fg"] = "#ffffff"
        WANInterfaceLabel["justify"] = "center"
        WANInterfaceLabel["text"] = "WAN Interface Number eg- 1/'X'"
        WANInterfaceLabel.place(x=20,y=225,width=260,height=25)

        PeerIPLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        PeerIPLabel["font"] = ft
        PeerIPLabel["bg"] = "#393d49"
        PeerIPLabel["fg"] = "#ffffff"
        PeerIPLabel["justify"] = "center"
        PeerIPLabel["text"] = "Peer IP Address"
        PeerIPLabel.place(x=20,y=275,width=260,height=25)

        WANIPLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        WANIPLabel["font"] = ft
        WANIPLabel["bg"] = "#393d49"
        WANIPLabel["fg"] = "#ffffff"
        WANIPLabel["justify"] = "center"
        WANIPLabel["text"] = "WAN IP Address"
        WANIPLabel.place(x=320,y=225,width=260,height=25)

        PSKLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        PSKLabel["font"] = ft
        PSKLabel["bg"] = "#393d49"
        PSKLabel["fg"] = "#ffffff"
        PSKLabel["justify"] = "center"
        PSKLabel["text"] = "Pre-Shared Key"
        PSKLabel.place(x=320,y=275,width=260,height=25)

        FirewallAddressLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        FirewallAddressLabel["font"] = ft
        FirewallAddressLabel["bg"] = "#393d49"
        FirewallAddressLabel["fg"] = "#ffffff"
        FirewallAddressLabel["justify"] = "center"
        FirewallAddressLabel["text"] = "Firewall IP Address"
        FirewallAddressLabel.place(x=20,y=75,width=260,height=25)

        FirewallUsernameLabel=tk.Label(root)
        ft = tkFont.Font(family='Verdana',size=10)
        FirewallUsernameLabel["font"] = ft
        FirewallUsernameLabel["bg"] = "#393d49"
        FirewallUsernameLabel["fg"] = "#ffffff"
        FirewallUsernameLabel["justify"] = "center"
        FirewallUsernameLabel["text"] = "Firewall Username"
        FirewallUsernameLabel.place(x=320,y=75,width=260,height=25)

#==========================================================================================================================================================================================
#GUI Entries
#----------------
             
        self.firewall_address=tk.StringVar()
        self.firewall_username=tk.StringVar()
        self.firewall_password=tk.StringVar()
        self.team_number=tk.StringVar()
        self.kit_number=tk.StringVar()
        self.int_number=tk.StringVar()
        self.wan_address=tk.StringVar()
        self.peer_address=tk.StringVar()
        self.pre_shared_key=tk.StringVar()

        WANInterfaceEntry=tk.Entry(root, textvariable=self.int_number)
        WANInterfaceEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        WANInterfaceEntry["font"] = ft
        WANInterfaceEntry["bg"] = "#5a6074"
        WANInterfaceEntry["fg"] = "#ffffff"
        WANInterfaceEntry["justify"] = "center"
        WANInterfaceEntry["relief"] = "flat"
        WANInterfaceEntry.place(x=20,y=250,width=260,height=25)

        TeamNumberEntry=tk.Entry(root, textvariable=self.team_number)
        TeamNumberEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        TeamNumberEntry["font"] = ft
        TeamNumberEntry["bg"] = "#5a6074"
        TeamNumberEntry["fg"] = "#ffffff"
        TeamNumberEntry["justify"] = "center"
        TeamNumberEntry["relief"] = "flat"
        TeamNumberEntry.place(x=20,y=200,width=260,height=25)

        PeerIPEntry=tk.Entry(root, textvariable=self.peer_address)
        PeerIPEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        PeerIPEntry["font"] = ft
        PeerIPEntry["bg"] = "#5a6074"
        PeerIPEntry["fg"] = "#ffffff"
        PeerIPEntry["justify"] = "center"
        PeerIPEntry["relief"] = "flat"
        PeerIPEntry.place(x=20,y=300,width=260,height=25)

        PSKEntry=tk.Entry(root, textvariable=self.pre_shared_key)
        PSKEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        PSKEntry["font"] = ft
        PSKEntry["bg"] = "#5a6074"
        PSKEntry["fg"] = "#ffffff"
        PSKEntry["justify"] = "center"
        PSKEntry["relief"] = "flat"
        PSKEntry.place(x=320,y=300,width=260,height=25)

        WANIPEntry=tk.Entry(root, textvariable=self.wan_address)
        WANIPEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        WANIPEntry["font"] = ft
        WANIPEntry["bg"] = "#5a6074"
        WANIPEntry["fg"] = "#ffffff"
        WANIPEntry["justify"] = "center"
        WANIPEntry["relief"] = "flat"
        WANIPEntry.place(x=320,y=250,width=260,height=25)

        KitNumberEntry=tk.Entry(root, textvariable=self.kit_number)
        KitNumberEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        KitNumberEntry["font"] = ft
        KitNumberEntry["bg"] = "#5a6074"
        KitNumberEntry["fg"] = "#ffffff"
        KitNumberEntry["justify"] = "center"
        KitNumberEntry["relief"] = "flat"
        KitNumberEntry.place(x=320,y=200,width=260,height=25)

        PasswordEntry=tk.Entry(root, textvariable=self.firewall_password)
        PasswordEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        PasswordEntry["font"] = ft
        PasswordEntry["bg"] = "#5a6074"
        PasswordEntry["fg"] = "#ffffff"
        PasswordEntry["justify"] = "center"
        PasswordEntry["relief"] = "flat"
        PasswordEntry.place(x=40,y=150,width=520,height=25)
        PasswordEntry["show"] = "*"

        FirewallAddressEntry=tk.Entry(root, textvariable=self.firewall_address)
        FirewallAddressEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        FirewallAddressEntry["font"] = ft
        FirewallAddressEntry["bg"] = "#5a6074"
        FirewallAddressEntry["fg"] = "#ffffff"
        FirewallAddressEntry["justify"] = "center"
        FirewallAddressEntry["relief"] = "flat"
        FirewallAddressEntry.place(x=20,y=100,width=260,height=25)

        FirewallUsernameEntry=tk.Entry(root, textvariable=self.firewall_username)
        FirewallUsernameEntry["borderwidth"] = "1px"
        ft = tkFont.Font(family='Verdana',size=10)
        FirewallUsernameEntry["font"] = ft
        FirewallUsernameEntry["bg"] = "#5a6074"
        FirewallUsernameEntry["fg"] = "#ffffff"
        FirewallUsernameEntry["justify"] = "center"
        FirewallUsernameEntry["relief"] = "flat"
        FirewallUsernameEntry.place(x=320,y=100,width=260,height=25)

#==========================================================================================================================================================================================
#GUI Buttons
#----------------

        DEPLOY_Button=tk.Button(root)
        DEPLOY_Button["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Verdana',size=10)
        DEPLOY_Button["font"] = ft
        DEPLOY_Button["bg"] = "#5a6074"
        DEPLOY_Button["fg"] = "#ffffff"
        DEPLOY_Button["justify"] = "center"
        DEPLOY_Button["text"] = "Deploy"
        DEPLOY_Button.place(x=120,y=350,width=70,height=25)
        DEPLOY_Button["command"] = self.DEPLOY_ButtonAction

        DESTROY_Button=tk.Button(root)
        DESTROY_Button["bg"] = "#e9e9ed"
        ft = tkFont.Font(family='Verdana',size=10)
        DESTROY_Button["font"] = ft
        DESTROY_Button["bg"] = "#5a6074"
        DESTROY_Button["fg"] = "#ffffff"
        DESTROY_Button["justify"] = "center"
        DESTROY_Button["text"] = "Destroy"
        DESTROY_Button.place(x=410,y=350,width=70,height=25)
        DESTROY_Button["command"] = self.DESTROY_ButtonAction

#==========================================================================================================================================================================================
#==========================================================================================================================================================================================
#==========================================================================================================================================================================================
#Main Flow
#----------------

if __name__ == "__main__":
    root = tk.Tk()
    app = App(root)
    root.mainloop()
