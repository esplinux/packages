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

//#ifndef IP_DF
//#define IP_DF 0x4000  /* don't fragment flag. */
//#endif

#define BUF_SIZE 8192
#define DEFAULT_ACTION "/etc/ifplugd/ifplugd.action"

GLOBALS(
  int unused;
)

void create_socket(int32_t *sd, struct sockaddr_nl *nl) {
    *sd = socket(AF_NETLINK, SOCK_DGRAM, NETLINK_ROUTE);
    if (*sd == -1) {
        error_exit("Socket error");
    }

    if ( bind(*sd, (struct sockaddr *) nl, sizeof( struct sockaddr_nl)) == -1) {
        error_exit("Bind error");
    }
}

void run(char **command) {
    pid_t pid = fork();

    if (pid == -1) {
        error_exit("Fork failed");
    } else if (pid == 0) {
        // we are the child
        execvp(command[0], command);
        error_exit("%s error", command[0]);
    }
}

ssize_t send_message(int32_t *sd, struct nlmsghdr *hdr, struct sockaddr_nl *nl) {
    struct iovec *iov = xmalloc(sizeof(struct iovec));
    iov->iov_base = hdr;
    iov->iov_len = hdr->nlmsg_len;

    struct msghdr *msg = xmalloc(sizeof(struct msghdr));;
    msg->msg_name = nl;
    msg->msg_namelen = sizeof(struct sockaddr_nl);
    msg->msg_iov = iov;
    msg->msg_iovlen = 1;

    ssize_t msg_len = sendmsg(*sd, msg, 0);
    if (msg_len < 0) {
        error_exit("netlink send failed: %s", strerror(errno));
    }

    free(iov);
    free(msg);

    return msg_len;
}

ssize_t receive_message(int32_t *sd, char *buf, struct sockaddr_nl *nl) {
    struct iovec *iov = xmalloc(sizeof(struct iovec));
    iov->iov_base = buf;
    iov->iov_len = sizeof(char[BUF_SIZE]);

    struct msghdr *msg = xmalloc(sizeof(struct msghdr));
    msg->msg_name = nl;
    msg->msg_namelen = sizeof(struct sockaddr_nl);
    msg->msg_iov = iov;
    msg->msg_iovlen = 1;

    ssize_t msg_len = recvmsg(*sd, msg, 0);
    if (msg_len < 0) {
        error_exit(stderr, "netlink read failed: %s", strerror(errno));
    }

    free(iov);
    free(msg);

    return msg_len;
}

void init_interfaces(void) {
    struct nlmsghdr hdr;
    struct sockaddr_nl nl;
    char buf[BUF_SIZE];
    int32_t sd;

    memset(&nl, 0, sizeof(nl));
    nl.nl_family = AF_NETLINK;

    create_socket(&sd, &nl);

    memset(&hdr, 0, sizeof(hdr));
    hdr.nlmsg_len = NLMSG_LENGTH(sizeof(struct rtgenmsg));
    hdr.nlmsg_type = RTM_GETLINK;
    hdr.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
    hdr.nlmsg_pid = (__u32) getpid();
    hdr.nlmsg_seq = 1;

    send_message(&sd, &hdr, &nl);

    ssize_t msg_len = receive_message(&sd, buf, &nl);

    struct nlmsghdr *nlmsg = (struct nlmsghdr *) buf;
    while (NLMSG_OK(nlmsg, msg_len)) {
        if (nlmsg->nlmsg_type != RTM_NEWLINK) continue;

        struct ifinfomsg *ifi = NLMSG_DATA(nlmsg);
        struct rtattr *attr = IFLA_RTA(ifi);
        uint32_t attr_len = nlmsg->nlmsg_len - NLMSG_LENGTH(sizeof(*ifi));

        while (RTA_OK(attr, attr_len)) {
            if (attr->rta_type == IFLA_IFNAME) {
                char *ifName = (char *) RTA_DATA(attr);
                run((char *[]) {DEFAULT_ACTION, ifName, "init", 0});
            }
            attr = RTA_NEXT(attr, attr_len);
        }
        nlmsg = NLMSG_NEXT(nlmsg, msg_len);
    }

    close(sd);
}


void ifplugd(void) {
    struct sockaddr_nl nl;
    char buf[BUF_SIZE];
    int32_t sd;

    memset(&nl, 0, sizeof(nl));
    nl.nl_family = AF_NETLINK;
    nl.nl_groups = RTMGRP_LINK;

    create_socket(&sd, &nl);

    while (1) {
        ssize_t msg_len = receive_message(&sd, buf, &nl);

        struct nlmsghdr *nlmsg = (struct nlmsghdr *) buf;
        while (NLMSG_OK(nlmsg, msg_len)) {
            if (nlmsg->nlmsg_type != RTM_NEWLINK) continue;

            struct ifinfomsg *ifi = NLMSG_DATA(nlmsg);
            struct rtattr *attr = IFLA_RTA(ifi);
            uint32_t attr_len = nlmsg->nlmsg_len - NLMSG_LENGTH(sizeof(*ifi));

            while (RTA_OK(attr, attr_len)) {
                if (attr->rta_type == IFLA_IFNAME) {
                    char *ifName = (char *) RTA_DATA(attr);
                    if (ifi->ifi_flags & IFF_RUNNING) { // get UP flag of the network interface
                        run((char *[]) {DEFAULT_ACTION, ifName, "up", 0});
                    } else {
                        run((char *[]) {DEFAULT_ACTION, ifName, "down", 0});
                    }
                }
                attr = RTA_NEXT(attr, attr_len);
            }

            nlmsg = NLMSG_NEXT(nlmsg, msg_len);
        }
    }

    close(sd);
}

void ifplugd_main(void)
{
    signal(SIGCHLD, SIG_IGN);
    init_interfaces();
    ifplugd();
}
