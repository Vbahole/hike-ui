# hike-ui


## Linux Getting Fried on Chromebook
Around the start of November 2020 the linux install on Lily's chromebook just stopped working - could not open the terminal, atom or access any files in the linux drive.  This really sucked. But I was able to disable then re-enable linux and it appears to be working now, but with none of my original files, updates, aliases or installs. but I learned a valuable lesson: 1. KEEP KEYPAIR FILES IN SEVERAL LOCATIONS. without them my ec2 instance is no longer accessible so i have to kill it. Not a really big deal but always keep the key files on the linux and local drives. Could still get lost if the chromebook dies.
Recovering from that (EC2):
1. kill the rogue ec2 instance
2. follow directions below to recreate it to where it was (could also just be using docker OR a custom aws ami image)
Recovering linux:
1. add aliases if you want to .bashrc
2. update everything
- `sudo apt-get update && sudo apt-get upgrade`
- `sudo apt-get install git`
- `wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add`
- `sudo sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'`
- `sudo apt-get install atom`

How much space is there after all of that? I think I set linux to 9 or 10 GB when i enabled it
gooss22@penguin:~$ df
Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/vdb        10066328 1869476   7279068  30% /
none                 492       0       492   0% /dev
devtmpfs         1420880       0   1420880   0% /dev/tty
/dev/vdb        10066328 1869476   7279068  30% /dev/wl0

OR use the handy shell script i wrote in the root of this repo. first `chmod +x linux-recovery.sh` then `./linux-recovery.sh`



## AWS - killing the web server and starting again
node and nvm got all jacked up on the webserver so i want to recreate it and start over.
Here are the instructions:

1. before we kill the existing webserver instance we need some info from it:
name: hike-webserver
Elastic IP address: 34.201.181.141 this associates the server with our DNS entry so you can get to it on the innernets. we need that on the replacement web server.
instance type:t2.micro
ami: aws linux 2 (ami id = ami-0947d2ba12ee1ff75)
keypair: hikewebserverkp
vpc: hike-vpc
sg: sg-072985519b3e6f0bd (webserver-sg) - for all of the ports to open

2. kill the instance - will lose all of the code and installs but it's all on git
3. launch new instance - enter name, sg, keypair, and launch!
4. associate elastic ip - go to ec2>elastic ip>associate and choose the new instance
5. try to connect via ssh to the new instance - may see a message about REMOTE HOST IDENTIFICATION HAS CHANGED follow the command they suggest and the error will go away and you can connect
6. run commands on instance to get it updated - these can also be included in the user data when spinning up the instance on the Configure Instance tab (you need the bin/bash if you go that route but not the sudo). also, decide if you want apache

`
#!/bin/bash
sudo yum update -y
yum install httpd -y
service httpd start
chkconfig httpd on
`

7. want node instead of apache run:
- curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
- . ~/.nvm/nvm.sh
- nvm install node
- npm --version
- nvm --version

8. how about git? sudo yum install git -y
9. now you can pull code over from git as a means to deploy
10. if you are running an express/node app on a port that port needs to be exposed as part of the inbound rules. Edit the security group, add an inbound custom TCP rule for that port and all from anywhere.
11. now you should be able to access the express site from both the ec2 public ip (ec2-34-201-181-141.compute-1.amazonaws.com:3100) or the DNS name (http://hike.vbahole.com:3100/)
12. nginx install - `sudo amazon-linux-extras install nginx1` then to fire it up `sudo systemctl start nginx` Now the home url (http://hike.vbahole.com/) should display the nginx page
13. Dockerize this entire workflow - then we don't need to install anything on the ec2 instance if we choose an ami that already has docker!


## css framework
going with boostrap since i don't know anything else

## js framework
maybe i need one? maybe i don't.

## ui needs data - get it by querying dynamo directly
one way to get the data is to pull it directly from dynamo when the ui page loads
that can be done via cognito to permit unauthorized access to dynamo via the web
these two docs were helpful for setting up cognito to allow DynamoDB access
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStarted.Js.Summary.html
https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Cognito.Credentials.html

created a cognito identity pool that allows unauth access
created a role that allows dynamo access
assigned that role to the cognito identity pool

## there has to be a better way - an api!
for one, I don't want the ui to even indicate that there is a dynamo table behind all of this. let alone show how it is being access via cognito - but it's right there in the code. my cognito pool id is visible in the script section of the index.html page. not sure if that is really a security hazard but there is a better way.....
the answer is to abstract all of the dynamo work to the api and have the ui call the api as needed.
the api ec2 instance now has rights to access dynamo as needed. I just need the ui to call the api for data.
not sure if this is enabled by default yet....it is not. fetching from the ui to
'http://ec2-54-89-84-212.compute-1.amazonaws.com:8081/stats' does not work...yet
maybe i need to be using the elastic ip of the api instance?
I think the reason this is not working is because it is the `browser` trying to call the api when it needs to be the server-side of the ui making the call.

## Using AWS Api Gateway
create an api gateway to sit in front of the api webserver and to broker calls to it.
i have a sample express api running on an ec2 instance but this could just as easily be a lamba or 2.
gateway supports either lambda or http backend `integrations`.

THIS DOCUMENTATION BELONGS IN THE LAMBDA repo
https://8tdvb17zme.execute-api.us-east-1.amazonaws.com/prod/stats
used a sample lambda application to create:
- api Gateway (along with a deployment and a stage named prod)
- lambda (along with a permission and an IAM role)

configured a gateway resource at GET /stats
which runs the lambda (no parameters needed) that queries dynamoDb for the overall stats
the api gateway handles the CORS so the gateway endpoint should work from the browser

MAJOR HASSLE trying to get cors working on the gateway api OPTIONS endpoint. first i tried to use the one that gateway generates by enabling cors and it was always screwed up and was not returning the proper allow-origin header. finally figured out that the sample code i was using acutally sets the response headers on the way out the door and that the `lamda proxy integration` puts them in the response. so i had to route the OPTIONS call to the lambda just like the GET call was. proxy integration is a way of telling lambda to take all of the headers and all of the other information that is NOT in the body and also make it available to the lambda code via the event object. So it works on the way in and on the way out to generate response headers. Once i got that header correct it started working. so now ui can hit api.....finally
