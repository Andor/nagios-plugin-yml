#!/usr/bin/perl -w

use strict;
use Nagios::Plugin;
use LWP::UserAgent;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Date::Parse;
use Date::Format;

my $np = Nagios::Plugin->new(
    usage => 'Usage: %s [--user HTTP USERNAME] [--password HTTP PASSWORD] [--max-age SECONDS] [--strict] [--offers] --url url [ url ..]',
);

$np->add_arg(
    spec => 'url=s@',
    help => 'Specify URL to check',
    required => 1,
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
$np->add_arg(
    spec => 'max-age|a=s',
    help => 'Check age of yml file',
    );
$np->add_arg(
    spec => 'offers|o',
    help => 'Check for count of offers in yml',
    default => 1,
    );
$np->getopts();

sub verbose {
    my $message = shift || return 1;
    if ( $np->opts->verbose ) {
        $|++;
        print "$message";
        $|--;
    }    
}

my $xc = XML::LibXML::XPathContext->new();

my $now = time();

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
                
                # create XPath object
                $xc->setContextNode( $dom );
                
                # Check last offers list update
                if ( $np->opts->get('max-age') ) {
                    my $date = $xc->findvalue('/yml_catalog/@date');
                    verbose "price date: $date\n";
                    
                    # check date format
                    if (! $date =~ m/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/ ) {
                        $np->add_message( CRITICAL, $req->uri.' has wrong date format: '.$date.';' );
                    } else {
                        $date = str2time($date);
                        # format pretty date
                        my $pretty_date = time2str("%d %h %R", $date);
                        my $diff = $now - $date;
                        
                        verbose "current time: $now; change time: $date; diff: $diff\n";
                        
                        if ( $diff > $np->opts->get('max-age') ) {
                            $np->add_message( CRITICAL, $req->uri." last update ". $pretty_date.';' );
                        } else {
                            $np->add_message( OK, $req->uri.' OK;' );
                        }
                    }

                } else {
                    $np->add_message( OK, $req->uri.': GET OK;' );
                }

                # Check count of offers
                if ( $np->opts->get('offers') ) {
                    my $offers_count = $xc->findvalue('count(/yml_catalog/shop/offers/offer)');
                    verbose "Number of offers: ".$offers_count."\n";
                    
                    if ( $offers_count > 0 ) {
                        $np->add_message( OK, $offers_count.' offers;' );
                    } else {
                        $np->add_message( CRITICAL, $req->uri.' has '.$offers_count.' offers;' );
                    }
                }

            } else {
                $np->add_message( CRITICAL, $req->uri.' has no XML elements;' );
            }
            
        } else{
                $np->add_message( CRITICAL, $req->uri.' content length is 0;' );
        }
    } else {
        $np->add_message( CRITICAL, 'Requesting '.$req->uri.' failed. Code '.$res->code.';' );
    }
}

my ( $code, $message ) = $np->check_messages();
$np->nagios_exit( $code, $message );
