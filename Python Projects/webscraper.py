import os,re,requests
from time import sleep
def ashes():
    sitestatus = requests.get('https://ashesofcreation.com/news')
    pattern = r'^2[0-9]{2}$'
    if re.match(pattern, str(sitestatus.status_code)):
        print("Website looks to be up. Response code is {0}.".format(sitestatus.status_code))
    else: print('Site seems down. Try again later.')
    for x in range(3):
        print(f'Loading site contents.{"." * (x + 1)}')
        sleep(1)
        os.system('cls')
ashes()