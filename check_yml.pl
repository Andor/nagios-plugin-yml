#!/usr/bin/perl -w

use strict;
use Nagios::Plugin;
use XML::LibXML;
use LWP::UserAgent;

my $np = Nagios::Plugin->new(
    usage => 'Usage: %s [--user HTTP USERNAME] [--password HTTP PASSWORD] url [url ..]',
);

$np->add_arg(
    spec => 'user|u=s',
    help => 'Specify HTTP username',
    );
$np->add_arg(
    spec => 'password|p=s',
    help => 'Specify HTTP password',
    );
$np->getopts();

# Create a user agent object
my $ua = LWP::UserAgent->new;
$ua->agent( 'check yml/0.1' );
foreach my $url (@ARGV) {
    # Create a request
    my $req = HTTP::Request->new( GET => $url );
    # Autorization
    $req->authorization_basic( $np->opts->user, $np->opts->password );

    # Handle response
    my $res = $ua->request( $req );

    # Check for not 200 return code
    if ( $res->code != 200 ) {
        $np->add_message( CRITICAL, 'Requesting '.$req->uri.' failed. Code '.$res->code );
    } else {
        if ( length( $res->content ) ) {
            my $dom = XML::LibXML->load_xml(
                string => $res->content
                );
            if ( $dom->indexElements() ) {
                $np->add_message( OK, $req->uri.' OK;' );
            } else {
                $np->add_message( CRITICAL, $req->uri.' has no elements' );
            }
#            print $dom->indexElements()."\n";
        } else{
            $np->add_message( CRITICAL, $req->uri.' content length is 0' );
        }
    }
}

my ( $code, $message ) = $np->check_messages();
$np->nagios_exit( $code, $message );
