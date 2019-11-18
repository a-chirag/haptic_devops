All the traffic comes to the private subnet via Demilitarized zone DMZ So that we have a control over the network coming from the outside world.

These ec2 instances are apache reverse proxy instances. Which just forwards the request to the private subnet.
