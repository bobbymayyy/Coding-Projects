import tkinter as tk

def clear_canvas():
    canvas.delete("all")  # Delete all items on the canvas

root = tk.Tk()
root.title("Clear Canvas Example")

canvas = tk.Canvas(root, width=400, height=300, bg="white")
canvas.pack()

# Create some items on the canvas (for demonstration purposes)
canvas.create_rectangle(50, 50, 150, 150, fill="blue")
canvas.create_oval(200, 50, 300, 150, fill="red")

# Button to clear the canvas
clear_button = tk.Button(root, text="Clear Canvas", command=clear_canvas)
clear_button.pack(pady=10)

root.mainloop()
