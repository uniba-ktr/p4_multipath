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

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        meta.tcpLength = hdr.ipv4.totalLen - (bit<16>)(hdr.ipv4.ihl)*4;
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action clone_packet() {
        const bit<32> REPORT_MIRROR_SESSION_ID = 500;
        //Clone from inggress to egress pipeline
        clone(CloneType.I2E, REPORT_MIRROR_SESSION_ID);


    }
    
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    apply {
        if(hdr.ipv4.isValid()) {
            //clone every packet
            if(standard_metadata.ingress_port == 1) {
                clone_packet();  
            }
              
            
            ipv4_lpm.apply();
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