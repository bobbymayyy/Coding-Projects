import tkinter as tk
import tkinter.font as tkFont

class App:
    def __init__(self, root):
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

        GLineEdit_746=tk.Entry(root)
        GLineEdit_746["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_746["font"] = ft
        GLineEdit_746["fg"] = "#333333"
        GLineEdit_746["justify"] = "center"
        GLineEdit_746["text"] = "team_number"
        GLineEdit_746.place(x=20,y=200,width=260,height=25)

        GLineEdit_265=tk.Entry(root)
        GLineEdit_265["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_265["font"] = ft
        GLineEdit_265["fg"] = "#333333"
        GLineEdit_265["justify"] = "center"
        GLineEdit_265["text"] = "peer_address"
        GLineEdit_265.place(x=20,y=300,width=260,height=25)

        GLineEdit_624=tk.Entry(root)
        GLineEdit_624["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_624["font"] = ft
        GLineEdit_624["fg"] = "#333333"
        GLineEdit_624["justify"] = "center"
        GLineEdit_624["text"] = "pre_shared_key"
        GLineEdit_624.place(x=320,y=300,width=260,height=25)

        GLineEdit_331=tk.Entry(root)
        GLineEdit_331["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_331["font"] = ft
        GLineEdit_331["fg"] = "#333333"
        GLineEdit_331["justify"] = "center"
        GLineEdit_331["text"] = "wan_address"
        GLineEdit_331.place(x=320,y=250,width=260,height=25)

        GLineEdit_881=tk.Entry(root)
        GLineEdit_881["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_881["font"] = ft
        GLineEdit_881["fg"] = "#333333"
        GLineEdit_881["justify"] = "center"
        GLineEdit_881["text"] = "kit_number"
        GLineEdit_881.place(x=320,y=200,width=260,height=25)

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

        GLineEdit_26=tk.Entry(root)
        GLineEdit_26["borderwidth"] = "1px"
        ft = tkFont.Font(family='Times',size=10)
        GLineEdit_26["font"] = ft
        GLineEdit_26["fg"] = "#333333"
        GLineEdit_26["justify"] = "center"
        GLineEdit_26["text"] = "firewall_username"
        GLineEdit_26.place(x=320,y=100,width=260,height=25)

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
        print("command")


    def GButton_872_command(self):
        print("command")

if __name__ == "__main__":
    root = tk.Tk()
    app = App(root)
    root.mainloop()
