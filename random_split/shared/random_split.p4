/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action random_split_group(bit<14> random_split_group_id, bit<16> threshold, bit<16> maxNum){
      bit<16> randomVal;
      random(randomVal, (bit<16>) 0, (bit<16>)maxNum);
      if(randomVal >= (bit<16>) threshold) {
        meta.random_split_port = (bit<14>) 0;
      } else {
        meta.random_split_port = (bit<14>) 1;
      }
       meta.random_split_group_id = random_split_group_id;
    }

    action set_nhop(macAddr_t dstAddr, egressSpec_t port) {
        meta.tcpLength = hdr.ipv4.totalLen - (bit<16>)(hdr.ipv4.ihl)*4;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        standard_metadata.egress_spec = port;

        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table random_split_group_to_nhop {
        key = {
            meta.random_split_group_id: exact;
            meta.random_split_port: exact;
        }
        actions = {
            drop;
            set_nhop;
        }
        size = 1024;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            set_nhop;
            random_split_group;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    apply {
        if(hdr.ipv4.isValid()) {
            switch(ipv4_lpm.apply().action_run) {
                random_split_group: { random_split_group_to_nhop.apply(); }
            }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {

    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
              hdr.ipv4.hdrChecksum,
              HashAlgorithm.csum16);
        update_checksum_with_payload(hdr.tcp.isValid(),
        {   hdr.ipv4.srcAddr,
            hdr.ipv4.dstAddr,
            8w0,
            hdr.ipv4.protocol,
            meta.tcpLength,
            hdr.tcp.srcPort,
            hdr.tcp.dstPort,
            hdr.tcp.seqNo,
            hdr.tcp.ackNo,
            hdr.tcp.dataOffset,
            hdr.tcp.res,
            hdr.tcp.cwr,
            hdr.tcp.ecn,
            hdr.tcp.urg,
            hdr.tcp.ack,
            hdr.tcp.psh,
            hdr.tcp.rst,
            hdr.tcp.syn,
            hdr.tcp.fin,
            hdr.tcp.window,
            hdr.tcp.urgentPtr},
            hdr.tcp.checksum, HashAlgorithm.csum16);
        update_checksum_with_payload(hdr.udp.isValid(),
        {   hdr.ipv4.srcAddr,
            hdr.ipv4.dstAddr,
            8w0,
            hdr.ipv4.protocol,
            meta.tcpLength,
            hdr.udp.srcPort,
            hdr.udp.dstPort,
            hdr.udp.length_,
            },
        hdr.udp.checksum, HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;