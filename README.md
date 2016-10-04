These instructions are based on using the [OpenShift Origin All-In-One
Virtual Machine](https://www.openshift.org/vm/).  You may have to adjust these instructions to work
with an alternative OpenShift environment.

Demonstration Scenario
----------------------
The scenario is documented in [section 4.5.2 of the A-MQ Interconnect
User Guide](https://access.redhat.com/documentation/en/red-hat-jboss-a-mq/7.0/using-a-mq-interconnect/#path_redundancy_and_temporal_decoupling) titled "Path Redundancy and Temporal Decoupling".

Install Dispatch Router Tools
-----------------------------
Follow the instructions in this section when launching the OpenShift
Origin guest for the first time or after doing a 'vagrant destroy'.
To launch the guest, use:

    cd <path-to-origin>
    vagrant up

Login to the guest instance using:

    vagrant ssh

Install the needed client tools to connect to the dispatch routers.

    sudo yum -y install python-qpid-proton

Create the Project in OpenShift
-------------------------------
Login to OpenShift and create the project:

    oc login 10.2.2.2:8443 -u user

Enter the password *user* when prompted.

    oc new-project qpidtest

Clone the repository to get needed configuration files:

    git clone https://github.com/rlucente-se-jboss/dispatch-router-demo.git
    cd dispatch-router-demo

The guest is pre-configured with several persistent volumes.  We'll
use one of these to hold the various configuration files for the
dispatch-routers.  Create a persistent volume claim for this project:

    oc create -f create-pvc.yaml

Check that the claim is bound by issuing the command:

    oc get pvc

The expected result is:

    NAME           STATUS    VOLUME    CAPACITY   ACCESSMODES   AGE
    config-claim   Bound     pv01      10Gi       RWO,RWX       5s 

Copy the router-*.conf files to the bound volume so that they'll
be available to the various dispatch-routers when they mount the
volume.

    sudo cp resources/*.conf /nfsvolumes/pv01
    sudo chmod -R a+rwX /nfsvolumes/pv01

Replace pv01 in the above commands with the actual bound volume
name.

Create a Broker Instance
------------------------

Create a single broker instance to hold messages as a waypoint.
The broker instance will take some time to start up.

    docker pull rmohr/activemq
    oc new-app rmohr/activemq

Create the ImageStream for the Router Apps
------------------------------------------
Create the application's imagestream using the commands:

    oc new-app https://github.com/rlucente-se-jboss/dispatch-router-demo.git \
        --name=dispatch-router --context-dir=dispatch-router --strategy=docker \
        -l name=dispatch-router

Follow the log for the build using:

    oc logs -f bc/dispatch-router

Wait until the build completes and the image is pushed to the
registry.  Then delete all the artifacts except for the imagestream
since we need only it to instantiate the individual routers.

    oc delete dc/dispatch-router
    oc delete service/dispatch-router

Create Application Template for Router Instances
------------------------------------------------
Use the following command to create a template for the individual
routers for this scenario.  Simple replacement of various router
strings can be used to instantiate the three router applications.

    oc new-app --image-stream=dispatch-router --name=router-a \
        -l name=router-a \
        -e QDROUTER_CONF=/etc/qpid-dispatch/router-a.conf \
        -o yaml > create-router-app.yaml

Edit the application yaml file to add the persistent volume claim
for the router configuration files and mount it at /etc/qpid-dispatch.
Make sure that the yaml file matches the following stanza:

      spec:
        containers:
        - env:
          - name: QDROUTER_CONF
            value: /etc/qpid-dispatch/router-a.conf
          image: 172.30.83.78:5000/qpidtest/amq-interconnect:latest
          name: router-a
          ports:
          - containerPort: 6000
            protocol: TCP
          - containerPort: 5000
            protocol: TCP
          - containerPort: 5673
            protocol: TCP
          volumeMounts:
          - mountPath: /etc/qpid-dispatch
            name: pvol
          resources: {}
        volumes:
          - name: pvol
            persistentVolumeClaim:
              claimName: config-claim
    test: false

Create the Router Instance
---------------------------
Now, we can finally create the three router instances based on the
imagestream and application template.  Create router-a:

    oc create -f create-router-app.yaml

Then create router-b:

    sed -i 's/router-a/router-b/g' create-router-app.yaml
    oc create -f create-router-app.yaml

And finally router-c:

    sed -i 's/router-b/router-c/g' create-router-app.yaml
    oc create -f create-router-app.yaml

Wait until the three router pods and the broker pod are running.
You can see them using:

    oc get pods

Create the Dispatch Console
---------------------------
The dispatch web console provides a view of the router configuration via a browser.  The following command builds and deploys the web console as a container:

    oc new-app https://github.com/rlucente-se-jboss/dispatch-router-demo.git \
        --name=dispatch-console --context-dir=dispatch-router-console \
        --strategy=docker -l name=dispatch-console

Expose the service to external users:

    oc expose service dispatch-console

Use Port Forwarding to Expose Router A
--------------------------------------

Establish port forwarding by opening a separate command line terminal
and connecting to the CDK guest VM:

    cd <path-to-cdk>/cdk/components/rhel/rhel-ose
    vagrant ssh

Get the list of pods for the routers:

    oc get pods

Note the pod name for router-a then type the following:

    oc port-forward router-a-1-ibzoy 5673:5673 6000:6000

Make sure to use the correct pod name for router-a as returned by
the 'oc get pods' command.

Execute the Demo Scenario
-------------------------

Get the python simple send and receive tools by grabbing the
qpid-proton source code:

    git clone https://github.com/apache/qpid-proton.git
    cd qpid-proton/examples/python

Send messages to the queue:

    python simple_send.py -a localhost:6000/my_queue -m 5

You will see 'all messages confirmed' since the broker is storing
the messages.  Next, receive the messages using:

    python simple_recv.py -a localhost:6000/my_queue -m 5

You will see the following output:

    {u'sequence': int32(1)}
    {u'sequence': int32(2)}
    {u'sequence': int32(3)}
    {u'sequence': int32(4)}
    {u'sequence': int32(5)}

The key takeaway is that the messages were held in the broker's
my_queue after transiting from the client -> router-a -> router-b
-> broker.  The reverse path was taken when the client read the
messages from router-a.

Now, check the resiliency of this solution.  Send messages and get
confirmation that all messages were confirmed:

    python simple_send.py -a localhost:6000/my_queue -m 5

Stop router-b by scaling it to zero:

    oc scale --replicas=0 rc/router-b-1

Attempt to read messages which will block:

    python simple_recv.py -a localhost:6000/my_queue -m 5

In a separate terminal window, do the following:

    cd <path-to-cdk>/cdk/components/rhel/rhel-ose
    vagrant ssh
    cd /nfsvolumes/pv01
    mv router-c.conf router-c.conf.bak
    cp router-b.conf router-c.conf

Make sure that the persistent volume matches the one bound from
earlier.  Edit the router-c.conf file and make sure that the router
stanza matches the following:

    router {
        mode: interior
        id: Router.C
    }

To restart router-c, we can simply delete the pod and let the
replication controller restart it:

    oc get pods

Note which pod is router-c and then:

    oc delete pod router-c-1-1xtiy

You will receive the messages on the queue via the path broker ->
router-c -> router-a -> client.

TODO: Understand why recovery can take several minutes after router
is restarted.

Using Management Tools
----------------------

You can easily use the qdstat and qdmanage command-line tools by
specifying the correct URL.  To do this, first get a list of the
running pods:

    oc get pods

Then for the desired router, you can enter the container using:

    oc rsh router-a-1-1btgz

Make sure that the router id matches that returned by the 'oc get
pods' command.  Finally, use the command line tools via:

    qdstat -b 127.0.0.1:6000 -va

which gets a list of the configured addresses.

Have Fun!
---------

You can edit the configuration files, for example, using:

    vi /nfsvolumes/pv01/router-a.conf

Then restart the relevant router by deleting the pod as before:

    oc get pods

Note which pod is router-a and then:

    oc delete pod router-a-1-5yxfr

What's Next
-----------

There are some settings in the router configuration files as well
as the amq-interconnect image that lay down the ground work for a
web console to manage and view the router configurations.  I'll
discuss that more in the next post.
