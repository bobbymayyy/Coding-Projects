#!/usr/bin/python3

import tkinter as tk
import tkinter.font as tkFont
from functools import partial
import pexpect

def remove_zeros(team_num):
    # Convert number to string to handle zeroes
    team_num = str(team_num)
    # Remove leading zero
    team_num = team_num.lstrip('0')
    # Remove trailing zero
    if team_num.endswith('0'):
        team_num = team_num[:-1]
    # Convert back to number for logic
    team_num = int(team_num)
    # If already mitigated then return otherwise remove all zeroes
    if team_num >= 255:
        team_num = str(team_num)
        team_num = team_num.replace('0', '')
        team_num = int(team_num)
        if team_num >= 255:
            team_num = 88
            return int(team_num)
        else:
            return int(team_num)
    else:
        return int(team_num)

def configure_firewall(commands, fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr, octet):
    success = False
    try:
        # Create SSH connection
        ssh_newkey = 'Are you sure you want to continue connecting'
        ssh_cmd = f'ssh {fw_user}@{fw_addr}'
        ssh_conn = pexpect.spawn(ssh_cmd, timeout=120)
        # Handle SSH key verification
        i = ssh_conn.expect([ssh_newkey, 'Password:', pexpect.EOF, pexpect.TIMEOUT])
        if i == 0:
            ssh_conn.sendline('yes')
            i = ssh_conn.expect([ssh_newkey, 'Password:', pexpect.EOF, pexpect.TIMEOUT])
        # Enter password
        if i == 1:
            ssh_conn.sendline(fw_pass)
        elif i == 2 or i == 3:
            raise Exception('SSH connection failed')
        # Wait for prompt
        ssh_conn.expect_exact('>')
        # Start configuration and wait for config prompt
        ssh_conn.sendline("set cli terminal width 500")
        ssh_conn.expect_exact('>')
        ssh_conn.sendline("set cli scripting-mode on")
        ssh_conn.expect_exact('>')
        ssh_conn.sendline("configure")
        ssh_conn.expect_exact('#')
        # Send commands
        if commands == "deploy":
            command_list = [
                f"set network interface tunnel units tunnel.{team_num} ip 192.168.{octet}.2/24",
                f"set network interface tunnel units tunnel.{team_num} mtu 1350",
                f"set network interface ethernet ethernet1/{int_num} layer3 ip {wan_addr}/28",
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
                f"set network tunnel ipsec CPT{team_num} tunnel-monitor destination-ip 192.168.{octet}.1 enable yes tunnel-monitor-profile default",
                f"set network virtual-router default protocol ospf router-id {wan_addr}",
                f"set network virtual-router default protocol ospf enable yes",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} enable yes",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} passive no",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} gr-delay 10",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} metric 10",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} priority 1",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} hello-interval 10",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} dead-counts 4",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} retransmit-interval 5",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} transit-delay 1",
                f"set network virtual-router default protocol ospf area 0.0.0.{octet} interface tunnel.{team_num} link-type p2p",
                f"set network virtual-router default protocol redist-profile Kit{kit_num} action redist",
                f"set network virtual-router default protocol redist-profile Kit{kit_num} priority 1",
                f"set network virtual-router default protocol redist-profile Kit{kit_num} filter type connect destination 10.{kit_num}.0.0/16",
                f"set network virtual-router default protocol ospf export-rules Kit{kit_num} new-path-type ext-2",
                f"set network virtual-router default protocol ospf enable yes area 0.0.0.{octet} type normal"
            ]
        elif commands == "destroy":
            command_list = [
                f"delete zone VPN network layer3 tunnel.{team_num}",
                f"delete network tunnel ipsec CPT{team_num}",
                f"delete network virtual-router default protocol ospf area 0.0.0.{octet}",
                f"set network virtual-router default protocol ospf enable no",
                f"delete network virtual-router default protocol ospf router-id",
                f"delete network virtual-router default interface tunnel.{team_num}",
                f"delete network virtual-router default protocol ospf export-rules Kit{kit_num}",
                f"delete network virtual-router default protocol redist-profile Kit{kit_num}",
                f"delete network ike gateway CPT{team_num}",
                f"delete network ike crypto-profiles ipsec-crypto-profiles CPT{team_num}",
                f"delete network ike crypto-profiles ike-crypto-profiles CPT{team_num}",
                f"delete network interface tunnel units tunnel.{team_num}",
                f"delete network interface ethernet ethernet1/{int_num} layer3 ip {wan_addr}/28"
            ]
        for command in command_list:
            ssh_conn.sendline(command)
            ssh_conn.expect_exact('#')
        ssh_conn.sendline("commit")
        ssh_conn.expect_exact('#')
        ssh_conn.sendline("exit")
        ssh_conn.expect_exact('>')
        ssh_conn.sendline("exit")
        ssh_conn.close()
        success = True
    except Exception as e:
        print(f"Error: {e}")
        if ssh_conn:
            ssh_conn.close()
    fw_pass = ""
    return success

#===================================================================================================================================
# Firewall Manager App
#===================================================================================================================================
class FirewallManager:
    def __init__(self, root):
        self.root = root
        self.create_gui()

    def create_gui(self):
        self.root.title("AutoVPN")
        self.root.geometry("600x400")
        self.root.resizable(False, False)
        self.root.configure(background='#393d49')
        self.create_labels()
        self.create_entries()
        self.create_buttons()
        self.configure_success = False

    def reset_app(self):
        # Reset labels with no user input to red font color
        default_labels = [
            ("Team Number", self.entries[2]),
            ("Kit Number", self.entries[3]),
            ("WAN Interface Number eg- 1/'X'", self.entries[4]),
            ("Peer IP Address", self.entries[6]),
            ("WAN IP Address", self.entries[5]),
            ("Pre-Shared Key", self.psk_entry),
            ("Please enter your password below:", self.password_entry),
            ("Firewall IP Address", self.entries[0]),
            ("Firewall Username", self.entries[1])
        ]
        self.welcome_label = tk.Label(self.root, text="Welcome to AutoVPN.", font=tkFont.Font(family='Verdana', size=30), bg="#393d49", fg="#ffffff", justify="center")
        self.welcome_label.place(x=20,y=10,width=560,height=70)
        for label_text, entry in default_labels:
            if not entry.get():
                label = [widget for widget in self.root.children.values() if isinstance(widget, tk.Label) and widget.cget('text') == label_text]
                if label:
                    label[0].config(fg="red")
            else:
                label = [widget for widget in self.root.children.values() if isinstance(widget, tk.Label) and widget.cget('text') == label_text]
                if label:
                    label[0].config(fg="#ffffff")

    def create_labels(self):
        labels_info = [
            ("Please enter your password below:", 170, 125, 260, 25),
            ("Team Number", 20, 175, 260, 25),
            ("Kit Number", 320, 175, 260, 25),
            ("WAN Interface Number eg- 1/'X'", 20, 225, 260, 25),
            ("Peer IP Address", 20, 275, 260, 25),
            ("WAN IP Address", 320, 225, 260, 25),
            ("Pre-Shared Key", 320, 275, 260, 25),
            ("Firewall IP Address", 20, 75, 260, 25),
            ("Firewall Username", 320, 75, 260, 25)
        ]
        self.welcome_label = tk.Label(self.root, text="Welcome to AutoVPN.", font=tkFont.Font(family='Verdana', size=30), bg="#393d49", fg="#ffffff", justify="center")
        self.welcome_label.place(x=20,y=10,width=560,height=70)
        for text, x, y, width, height in labels_info:
            label = tk.Label(self.root, text=text, font=tkFont.Font(family='Verdana', size=10), bg="#393d49", fg="#ffffff", justify="center")
            label.place(x=x, y=y, width=width, height=height)

    def create_entries(self):
        self.password_entry=tk.Entry(root, font=tkFont.Font(family='Verdana',size=10), bg="#5a6074", fg="#ffffff", justify="center", relief="flat", show="*")
        self.password_entry.place(x=40,y=150,width=520,height=25)
        self.psk_entry=tk.Entry(root, font=tkFont.Font(family='Verdana',size=10), bg="#5a6074", fg="#ffffff", justify="center", relief="flat", show="*")
        self.psk_entry.place(x=320,y=300,width=260,height=25)
        entries_info = [
            (20, 100, 260, 25),
            (320, 100, 260, 25),
            (20, 200, 260, 25),
            (320, 200, 260, 25),
            (20, 250, 260, 25),
            (320, 250, 260, 25),
            (20, 300, 260, 25),
        ]
        self.entries = [tk.Entry(root, font=tkFont.Font(family='Verdana',size=10), bg="#5a6074", fg="#ffffff", justify="center", relief="flat") for _ in range(len(entries_info))]
        for entry, (x, y, width, height) in zip(self.entries, entries_info):
            entry.place(x=x, y=y, width=width, height=height)

    def create_buttons(self):
        buttons_info = [
            ("Establish", self.deploy_button_action, 110, 345),
            ("Demolish", self.destroy_button_action, 400, 345)
        ]
        for text, command, x, y in buttons_info:
            button = tk.Button(self.root, text=text, font=tkFont.Font(family='Verdana',size=12), bg="#5a6074", fg="#ffffff", justify="center", relief="flat", command=command)
            button.place(x=x, y=y, width=90, height=30)

    def update_label_color(self, color):
        # Change color of welcome_label
        self.welcome_label.config(fg=color)

    def deploy_button_action(self):
        # Get input values from entries and perform deployment
        commands="deploy"
        fw_addr = self.entries[0].get()
        fw_user = self.entries[1].get()
        fw_pass = self.password_entry.get()
        team_num = self.entries[2].get()
        kit_num = self.entries[3].get()
        int_num = self.entries[4].get()
        wan_addr = self.entries[5].get()
        peer_addr = self.entries[6].get()
        psk_key = self.psk_entry.get()
        # Check if any input value is empty
        if any(value == "" for value in [fw_addr, fw_user, fw_pass, team_num, kit_num, int_num, wan_addr, peer_addr, psk_key]):
            print("Please fill in all fields.")
            self.reset_app()
            return
        else:
            self.reset_app()
            team_num = int(team_num)
            if team_num >= 255:
                octet = remove_zeros(team_num)
                self.configure_success = configure_firewall(commands, fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr, octet)
            else:
                octet = team_num
                self.configure_success = configure_firewall(commands, fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr, octet)
            if self.configure_success:
                self.update_label_color("#00ff00")

    def destroy_button_action(self):
        # Get input values from entries and perform deployment
        commands="destroy"
        fw_addr = self.entries[0].get()
        fw_user = self.entries[1].get()
        fw_pass = self.password_entry.get()
        team_num = self.entries[2].get()
        kit_num = self.entries[3].get()
        int_num = self.entries[4].get()
        wan_addr = self.entries[5].get()
        peer_addr = self.entries[6].get()
        psk_key = self.psk_entry.get()
        # Check if any input value is empty
        if any(value == "" for value in [fw_addr, fw_user, fw_pass, team_num, kit_num, int_num, wan_addr, peer_addr, psk_key]):
            print("Please fill in all fields.")
            self.reset_app()
            return
        else:
            self.reset_app()
            team_num = int(team_num)
            if team_num >= 255:
                octet = remove_zeros(team_num)
                self.configure_success = configure_firewall(commands, fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr, octet)
            else:
                octet = team_num
                self.configure_success = configure_firewall(commands, fw_addr, fw_user, fw_pass, team_num, kit_num, psk_key, peer_addr, int_num, wan_addr, octet)
            if self.configure_success:
                self.update_label_color("#00ff00")
            
#===================================================================================================================================
# Main Flow
#===================================================================================================================================
if __name__ == "__main__":
    root = tk.Tk()
    app = FirewallManager(root)
    root.mainloop()
