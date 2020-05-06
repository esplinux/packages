/* ifplugd.c - A simple ifplugd program. (Simple ifplug for network interfaces.)
 *
 * Copyright 2020 Eric Molitor <eric@molitor.org>
 *
 * See https://linux.dir.net/man/7/rtnetlink
 * See https://linux.dir.net/man/8/ifplugd

USE_IFPLUGD(NEWTOY(ifplugd, 0, TOYFLAG_NEEDROOT|TOYFLAG_SBIN))

config IFPLUGD
  bool "ifplugd"
  default y
  help
    usage: ifplugd

    A simple ifplugd program.

    Mostly used to configure static connections.
*/

#define FOR_ifplugd
#include "toys.h"
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/if_ether.h>
#include <linux/if_addr.h>
#include <net/if_arp.h>
#include <ifaddrs.h>
#include <fnmatch.h>
#include <linux/if_tunnel.h>

#ifndef IP_DF
#define IP_DF 0x4000  /* don't fragment flag. */
#endif

GLOBALS(
  int unused;
)

// little helper to parsing message using netlink macroses
void parseRtattr(struct rtattr *tb[], int max, struct rtattr *rta, int len)
{
  memset(tb, 0, sizeof(struct rtattr *) * (max + 1));

  while (RTA_OK(rta, len)) {  // while not end of the message
    if (rta->rta_type <= max) {
      tb[rta->rta_type] = rta; // read attr
    }
    rta = RTA_NEXT(rta,len);    // get next attr
  }
}

void ifplugd_main(void)
{
    int fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE);   // create netlink socket

    if (fd < 0) {
        error_exit("Failed to create netlink socket: %s\n", (char*)strerror(errno));
    }

    struct sockaddr_nl  local;  // local addr struct
    char buf[8192];             // message buffer
    struct iovec iov;           // message structure
    iov.iov_base = buf;         // set message buffer as io
    iov.iov_len = sizeof(buf);  // set size

    memset(&local, 0, sizeof(local));

    local.nl_family = AF_NETLINK;       // set protocol family
    local.nl_groups =   RTMGRP_LINK | RTMGRP_IPV4_IFADDR | RTMGRP_IPV4_ROUTE;   // set groups we interested in
    local.nl_pid = getpid();    // set out id using current process id

    // initialize protocol message header
    struct msghdr msg;  
    {
        msg.msg_name = &local;                  // local address
        msg.msg_namelen = sizeof(local);        // address size
        msg.msg_iov = &iov;                     // io vector
        msg.msg_iovlen = 1;                     // io size
    }   

    if (bind(fd, (struct sockaddr*)&local, sizeof(local)) < 0) {     // bind socket
        error_exit("Failed to bind netlink socket: %s\n", (char*)strerror(errno));
        //close(fd);
    }   

    // read and parse all messages from the
    while (1) {
        ssize_t status = recvmsg(fd, &msg, MSG_DONTWAIT);

        //  check status
        if (status < 0) {
            if (errno == EINTR || errno == EAGAIN)
            {
                usleep(250000);
                continue;
            }

            xprintf("Failed to read netlink: %s", (char*)strerror(errno));
            continue;
        }

        if (msg.msg_namelen != sizeof(local)) { // check message length, just in case
            xprintf("Invalid length of the sender address struct\n");
            continue;
        }

        // message parser
        struct nlmsghdr *h;

        for (h = (struct nlmsghdr*)buf; status >= (ssize_t)sizeof(*h); ) {   // read all messagess headers
            int len = h->nlmsg_len;
            int l = len - sizeof(*h);
            char *ifName;

            if ((l < 0) || (len > status)) {
                xprintf("Invalid message length: %i\n", len);
                continue;
            }

            // now we can check message type
            if ((h->nlmsg_type == RTM_NEWROUTE) || (h->nlmsg_type == RTM_DELROUTE)) { // some changes in routing table
                xprintf("Routing table was changed\n");  
            } else {    // in other case we need to go deeper
                char *ifUpp;
                char *ifRunn;
                struct ifinfomsg *ifi;  // structure for network interface info
                struct rtattr *tb[IFLA_MAX + 1];

                ifi = (struct ifinfomsg*) NLMSG_DATA(h);    // get information about changed network interface

                parseRtattr(tb, IFLA_MAX, IFLA_RTA(ifi), h->nlmsg_len);  // get attributes
                
                if (tb[IFLA_IFNAME]) {  // validation
                    ifName = (char*)RTA_DATA(tb[IFLA_IFNAME]); // get network interface name
                }

                if (ifi->ifi_flags & IFF_UP) { // get UP flag of the network interface
                    ifUpp = (char*)"UP";
                } else {
                    ifUpp = (char*)"DOWN";
                }

                if (ifi->ifi_flags & IFF_RUNNING) { // get RUNNING flag of the network interface
                    ifRunn = (char*)"RUNNING";
                } else {
                    ifRunn = (char*)"NOT RUNNING";
                }

                char ifAddress[256];    // network addr
                struct ifaddrmsg *ifa; // structure for network interface data
                struct rtattr *tba[IFA_MAX+1];

                ifa = (struct ifaddrmsg*)NLMSG_DATA(h); // get data from the network interface

                parseRtattr(tba, IFA_MAX, IFA_RTA(ifa), h->nlmsg_len);

                if (tba[IFA_LOCAL]) {
                    inet_ntop(AF_INET, RTA_DATA(tba[IFA_LOCAL]), ifAddress, sizeof(ifAddress)); // get IP addr
                }

                switch (h->nlmsg_type) { // what is actually happenned?
                    case RTM_DELADDR:
                        xprintf("Interface %s: address was removed\n", ifName);
                        break;

                    case RTM_DELLINK:
                        xprintf("Network interface %s was removed\n", ifName);
                        break;

                    case RTM_NEWLINK:
                        xprintf("New network interface %s, state: %s %s\n", ifName, ifUpp, ifRunn);
                        break;

                    case RTM_NEWADDR:
                        xprintf("Interface %s: new address was assigned: %s\n", ifName, ifAddress);
                        break;
                }
            }

            status -= NLMSG_ALIGN(len); // align offsets by the message length, this is important

            h = (struct nlmsghdr*)((char*)h + NLMSG_ALIGN(len));    // get next message
        }

        usleep(250000); // sleep for a while
    }

  //xprintf("Hello world\n");

  // Avoid kernel panic if run as init.
  //if (getpid() == 1) wait(&TT.unused);
}
