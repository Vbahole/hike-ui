# hike-ui


## Linux Getting Fried on Chromebook
Around the start of November 2020 the linux install on Lily's chromebook just stopped working - could not open the terminal, atom or access any files in the linux drive.  This really sucked. But I was able to disable then re-enable linux and it appears to be working now, but with none of my original files, updates, aliases or installs. but I learned a valuable lesson: 1. KEEP KEYPAIR (.pem) FILES IN SEVERAL LOCATIONS. without them my ec2 instance is no longer accessible so i have to kill it. Not a really big deal but always keep the key files on the linux and local drives. Could still get lost if the chromebook dies.
### Recovering EC2 Instances:
1. kill the rogue ec2 instance
2. follow directions below to recreate it to where it was (could also just be using docker OR a custom aws ami image)  
### Recovering linux(beta) on Chromebook:
1. add aliases if you want to .bashrc
2. update everything
- `sudo apt-get update && sudo apt-get upgrade`
- `sudo apt-get install git`
- `wget -qO - https://packagecloud.io/AtomEditor/atom/gpgkey | sudo apt-key add`
- `sudo sh -c 'echo "deb [arch=amd64] https://packagecloud.io/AtomEditor/atom/any/ any main" > /etc/apt/sources.list.d/atom.list'`
- `sudo apt-get install atom`

OR use the handy shell script [chrome-linux-recovery.sh](https://raw.githubusercontent.com/Vbahole/hike-ui/master/chrome-linux-recovery.sh) I wrote. first `chmod +x linux-recovery.sh` then `./linux-recovery.sh`

### space 
How much space is there after all of that if we start with a 9GB install? 
run `df`  
/dev/vdb 33% /  
/dev/vdb 33% /dev/wl0

## AWS - killing the web server and starting again
node and nvm got all jacked up on the webserver so i want to recreate it and start over.
Here are the instructions:

1. before we kill the existing webserver instance we need some info from it:
- name: hike-webserver
- Elastic IP address: 34.201.181.141 this associates the server with our DNS entry so you can get to it on the innernets. we need that on the replacement web server.
- instance type:t2.micro
- ami: aws linux 2 (ami id = ami-0947d2ba12ee1ff75)
- keypair: hike-kp
- vpc: hike-vpc
- sg: sg-072985519b3e6f0bd (webserver-sg) - for all of the ports to open

2. kill the instance - will lose all of the code and installs but it's all on git
3. launch new instance - select ami, sg, user data [ec2-user-data](https://raw.githubusercontent.com/Vbahole/hike-ui/master/ec2-user-data), Name tag, keypair, and launch!
4. associate elastic ip - go to ec2>elastic ip>associate and choose the new instance
5. try to connect via ssh to the new instance - may see a message about REMOTE HOST IDENTIFICATION HAS CHANGED follow the command they suggest and the error will go away and you can connect
6. now you can pull code over from git as a means to deploy
7. if you are running an express/node app on a port that port needs to be exposed as part of the inbound rules. Edit the security group, add an inbound custom TCP rule for that port and all from anywhere.
8. now you should be able to access the express site from both the ec2 public ip (ec2-34-201-181-141.compute-1.amazonaws.com:3100) or the DNS name (http://hike.vbahole.com:3100/)
9. Dockerize this entire workflow - then we don't need to install anything on the ec2 instance if we choose an ami that already has docker!

### Configure git
this is for the chromebook terminal (not ec2 instances)
`git config --global user.email "gooss22@gmail.com"`
`git config --global user.name "Vbahole"`
but it keeps asking for pw every time

### The Most Important Settings for nginx and angular to play nice together
1. the nginx configuration file at `/etc/nginx/nginx.conf`
```
 server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html/hike-ng/angularmaterial;
        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
             try_files $uri $uri/ /index.html;
        }
```
the important bits are:
- root - this points to a folder named hike-ng in the default location that nginx stores things. there is an index.html file at the location as a result of the `prod-build` process from npm in the angular app. There is also an index.html file at `/usr/share/nginx/html` but that is the default nginx page which you probably don't want to serve
- try_files [Routed apps must fallback to index.html](https://angular.io/guide/deployment#routed-apps-must-fallback-to-indexhtml). This is because angular has its own routing and doesn't need server-side help. If you refresh a page with a deep angular link that resource doesn't technically exist. angular makes it look like it does from the router in index.html. Therefore, you need to tell your web server (nginx) that when a request comes in that can't be served - don't panic - just point that request to index.html instead of an ugly 404 page or something.
2. angular's base-href - inside of the angular index.html file right near the title is the tag `<base href="/">`. That thing corresponds to any directories you are storing the content under. If you want to serve multiple sites from nginx you can do that with server/location blocks in the config. But angular needs to know that when it requests resources there may be a directory structure it needs to follow. In this case its root `/` because that is the root we setup in nginx above.

### nginx setup
On the new ec2 instance if you `curl http://localhost` you will get the nginx test page back. 
The elastic ip is rigged to route 53 so [hike](http://hike.vbahole.com/) should also load this test page, as will the [elastic ip](http://34.201.181.141/)  
We just need to get some web code out there to run inside of nginx/node.  
On the ec2 instance we need to start routing traffic through nginx.  

nginx configuration files are in `/etc/nginx/`  
nginx default web content `/usr/share/nginx/html`  

cd to `/etc/nginx/` and backup nginx.conf `sudo cp nginx.conf nginx.conf.bak` so we can start to edit it
the default root location listed in there will be `/usr/share/nginx/html`  
edit the root location to point to our code.  

### publish
right now the publish process is `npm run-script build --prod` which will [scp](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html) the files out in the ec2-user root on the instance
then that is copied to the default nginx web content location `/usr/share/nginx/html/hike-ng/angularmaterial`

```
"build-prod": "ng build --prod && 
scp -r -i hike-kp.pem ./dist/angularmaterial ec2-user@ec2-34-201-181-141.compute-1.amazonaws.com:/home/ec2-user/hike-ng/",
```
that then requires an extra hop within the ec2 instance to copy the files over to the nginx home: 
`sudo cp -r /home/ec2-user/hike-ng /usr/share/nginx/html/hike-ng`

we could skip that hop if we modify the build script to be:
`"build-prod": "ng build --prod && sudo scp -r -i hike-kp.pem ./dist/angularmaterial ec2-user@ec2-34-201-181-141.compute-1.amazonaws.com:/usr/share/nginx/html/hike-ng",
`
but always get permission denied - oh well


### useful nginx command
Restart the nginx service `sudo service nginx restart`
`cd /usr/share/nginx/` 
`cd /usr/share/nginx/html/`  
`sudo nano nginx.conf` 
`cd /etc/nginx/` 
`sudo nginx -s reload`  

#### getting the app to build
run `npm install` to get all of the packages under src. And then we need to get angular up and running with `ng build`
but first we need angular `npm install -g @angular/cli` then `ng build` then `ng s -o`

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
