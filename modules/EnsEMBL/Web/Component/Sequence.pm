package EnsEMBL::Web::Component::Sequence;

# Puts together chunks of XHTML for sequence-based displays

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

use Bio::AlignIO;

sub id {
  my( $panel, $object ) = @_;
  if( $object->param('id') ) {
    $panel->add_row( 'Sequence ID', sprintf( '<p>%s</p>', $object->param('id') ) );
  }
  return 1;
}

sub __meta {
  my( $panel, $object, $caption, $key ) = @_;
  $key ||= lc($caption);
  $key =~ s/ /_/g;
  my $val = $object->fetch_fastaMeta($key);
  if( $val ) {
    $val =~ s/\n/<\/p>\n<p>/g;
    $val =~ s/<br>/<br \/>\n/g;
    $panel->add_row( $caption, "<p>$val</p>" );
  }
  return 1;
}

sub meta_description { return __meta( @_, 'Description',  ); }
sub library          { return __meta( @_, 'Library',      ); }
sub meta_methods     { return __meta( @_, 'Methods',      ); }
sub meta_credits     { return __meta( @_, 'Credits',      ); }
sub genome_locations { return __meta( @_, 'Genome Locations' ); }
sub group_members    { return __meta( @_, 'Group Members' ); }

sub meta_links{
  my( $panel, $object ) = @_;
  my $links = $object->fetch_fastaMeta('links');
  if( $links ) {
    $panel->add_row( 'Links',qq(<p><a href="$links">$links</a></p>));
  }
  return 1;
}

sub sequence{
  my( $panel, $object ) = @_;
  my $wrap = $object->param( 'wrap' ) || 60;   
  for my $hashref ( $object->fetch_fastaData ) {
    next unless $hashref->{'sequence'};
    my $string = uc($hashref->{'sequence'});
    $string =~ s/([\w\*]{$wrap})/$1<br \/>/g;        
    my $header = $hashref->{'id'}." ".$hashref->{'description'};
    $panel->add_row( "Sequence of ".$hashref->{'id'}." ".$hashref->{'description'},
                    "<p><code>$string</code></p>" );
  }
  return 1;
}

1;
