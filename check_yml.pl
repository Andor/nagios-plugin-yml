#!/usr/bin/perl -w

use strict;
use Nagios::Plugin;
use XML::LibXML;
use LWP::UserAgent;

my $np = Nagios::Plugin->new(
    usage => 'Usage: %s [--user HTTP USERNAME] [--password HTTP PASSWORD] [--strict] [--url url] [ url ..]',
);

$np->add_arg(
    spec => 'url=s@',
    help => 'Specify URL to check',
    );
$np->add_arg(
    spec => 'user|u=s',
    help => 'Specify HTTP username',
    );
$np->add_arg(
    spec => 'password|p=s',
    help => 'Specify HTTP password',
    );
$np->add_arg(
    spec => 'strict',
    help => 'Strict check for 200 HTTP responce code',
    default => 1,
    );
$np->getopts();

sub verbose {
    my $message = shift;
    if ( $np->opts->verbose ) {
        $|++;
        print "$message";
        $|++;
    }    
}

# Create a user agent object
my $ua = LWP::UserAgent->new;
$ua->agent( 'check yml/0.1' );
foreach my $url (@{$np->opts->url}, @ARGV) {
    # Create a request
    verbose "Requesting $url : ";

    my $req = HTTP::Request->new( GET => $url );
    # Autorization
    $req->authorization_basic( $np->opts->user, $np->opts->password );

    # Handle response
    my $res = $ua->request( $req );

    verbose $res->code."\n";

    if ( $res->is_success ) {
        if ( $np->opts->strict ) {
            # Check for not 200 return code
            if ( $res->code != 200 ) {
                $np->add_message( CRITICAL, 'Requesting '.$req->uri.' is not 200 OK' );
            }
        }
        if ( length( $res->content ) ) {
            my $dom = XML::LibXML->load_xml(
                string => $res->content
                );
            verbose "Content length: ".length( $res->content )."\n";
            
            if ( $dom->indexElements() ) {
                verbose "Number of elements: ".$dom->indexElements."\n";
                
                $np->add_message( OK, $req->uri.' OK;' );
            } else {
                $np->add_message( CRITICAL, $req->uri.' has no elements' );
            }
            
        } else{
                $np->add_message( CRITICAL, $req->uri.' content length is 0' );
        }
    } else {
        $np->add_message( CRITICAL, 'Requesting '.$req->uri.' failed. Code '.$res->code );
    }
}

my ( $code, $message ) = $np->check_messages();
$np->nagios_exit( $code, $message );
