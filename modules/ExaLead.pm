=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package ExaLead;
use strict;

### The Exalead class heirarchy is a Perl wrapper around the Exalead one
### XML search engine output

## packages used to grab content of XML
use XML::Simple;
use LWP;
use CGI;

use ExaLead::SpellingSuggestion;
use ExaLead::Keyword;
use ExaLead::Query;
use ExaLead::QueryParameter;
use ExaLead::QueryTerm;
use ExaLead::TextSeg;
use ExaLead::Value;
use ExaLead::Group;
use ExaLead::Category;
use ExaLead::Link;
use ExaLead::Hit;
use ExaLead::HitGroup;
use ExaLead::HitCategory;

sub new {
### c
### Store information about hits
  my( $class ) = @_;
  my $self = {
    'engineURL'  => '',
    'rootURL'    => '',
    'nmatches'  => 0,
    'nhits'     => 0,
    'start'     => 0,
    'end'       => 0,
    'last'      => 0,
    'estimated' => 0,
    'keywords'  => [],
    'spellings' => [],
    'groups' => [],
    'hits'   => [],
    'query_string' => '',
    'hidden_fields' => [],
    '__status'      => 'no_search',
    '__error'       => undef,
    '__timeout'     => 30
  };
  bless $self, $class;
  return $self;
}

sub __timeout :lvalue {
### a
### Sets the timeout period for XML retrival
  $_[0]->{'__timeout'};
}

sub __status :lvalue {
### a
### either 'no_search', 'search' or 'failure'
  $_[0]->{'__status'};
}

sub __error :lvalue {
### a
### error string if failure occurs
  $_[0]->{'__error'};
}

sub engineURL :lvalue {
### a
### URL for search engine itself - that generates the XML hits
  $_[0]->{'engineURL'};
}

sub rootURL   :lvalue {
### a
### URL for the wrapper script
  $_[0]->{'rootURL'};
}

sub nmatches  :lvalue {
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'nmatches'};
}
sub nhits     :lvalue {
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'nhits'};
}
sub start     :lvalue {
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'start'};
}
sub end       :lvalue {
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'end'};
}
sub last      :lvalue { 
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'last'};
}
sub estimated :lvalue {
### a
### Taken from <Hits> element of the XML returned
  $_[0]->{'estimated'};
}

sub query :lvalue {
### a
### get/set {{Exalead::Query}} object, which summarises the
### query that was sentto the sarch engine
  $_[0]->{'query'};
}

sub addGroup  {
### Add a {{Exalead::Query}} object - these are used to hold the different
### categorisation of matches (in Ensembl's case these
### are Feature type and Species)
  push @{$_[0]{'groups'}}, $_[1];
}
sub addSpellingSuggestion  {
### Add a {{Exalead::SpellingSuggestion}} object - exalead comes back with
### alternative spellings if it cannot find the requested ID
  push @{$_[0]{'spellings'}}, $_[1];
}
sub addKeyword  {
### Add a {{Exalead::Keyword}} object
  push @{$_[0]{'keywords'}}, $_[1];
}
sub addHit      {
### Add a {{Exalead::Hit}} object - these are the actual URL responses
### for "pages" which match the request.
 push @{$_[0]{'hits'}},   $_[1];
}

sub groups {
### Returns array of {{Exalead::Group}} objects previously added
  return @{$_[0]{'groups'}};
}
sub spellingsuggestions {
### Returns array of {{Exalead::SpellingSuggestion}} objects previously added
  return @{$_[0]{'spellings'}};
}
sub keywords {
### Returns array of {{Exalead::Keywords}} objects previously added
 return @{$_[0]{'keywords'}};
}
sub hits   {
### Returns array of {{Exalead::Hits}} objects previously added
  return @{$_[0]{'hits'}};
}

## Parser and associated functions...

sub parse {
### Main function in the Exalead module, constructs the approprate request URL,
### and retrieves the XML, which then calls the inner function _parse, which
### actually parses the XML created the Exalead::* objects
  my( $self, $q, $flag ) = @_;
  my $search_URL = $self->engineURL;
#  my $host = `hostname`; chomp $host;
#  $host.=':'.gmtime();
  if( $flag > 20 ) {
#warn "[EXALEAD:$host:$$] $search_URL :FAIL: Exalead search engine failure\n";
    $self->__status = 'failure';
    $self->__error  = 'Exalead search engine failure';
    return;
  }
# $search_URL =~ s/1/2/;
  my $join = '?';
  foreach my $VAR ( $q->param() ) {
    $search_URL .= $join. join( '&', map { "$VAR=".CGI::escape($_) } $q->param( $VAR ) );
    $join = '&';
  }
  my $ua = LWP::UserAgent->new();
     $ua->timeout( $self->__timeout ); ## Allow 30 seconds for a response!!
  my $res = $ua->get( $search_URL );
  $self->{'search_URL'} = $search_URL;
  if( $res->is_success ) {
#warn "[EXALEAD:$host:$$] $search_URL ".length($res->content)." bytes\n";
    if( length( $res->content ) < 100 ) {
      $flag++;
#warn "[EXALEAD:$host:$$] rerunning $flag due to null response\n";
      sleep 1;
      return $self->parse( $q, $flag );
    }
    $self->_parse( $res->content );
  } else {
#warn "[EXALEAD:$host:$$] $search_URL :FAIL: ",$res->message,"\n";
    $self->__status = 'failure';
    $self->__error  = $res->message eq 'read timeout' ? 'Exalead search engine timed out after '.$self->__timeout.' seconds' : $res->message;
  }
}

sub _parse {
### The guts of the parser, takes an XML string, and converts it into a nested hash/array
### data structure using XML::Simple, which is then traversed to store the results
### returned by the search engine for later use
  my( $self, $XML ) = @_;
## Convert XML to object hash....
  my $xml = eval { XMLin( $XML, ForceArray=>1, KeyAttr=>[] ) };
  if( $@ ) {
    $self->__status = 'failure';
    (my $error = $@) =~ s/ at \/.*/./sm;
    $self->__error  = $error;
    return;
  } 
  $self->{'raw_XML'} = $XML;
  $self->{'XML'} = $xml;
  $self->__status = 'search';
## Parse Query....
  my $Q = $xml->{'Query'}[0];
  my $query = new ExaLead::Query( $Q->{'query'}, $Q->{'context'} );
  foreach my $qt_xml ( @{$Q->{'QueryTerm'}} ) {
    $query->addTerm( new ExaLead::QueryTerm( $qt_xml->{'regexp'}, $qt_xml->{'level'} ) );
  }
  foreach my $qp_xml ( @{$Q->{'QueryParameter'}} ) {
    $query->addParameter( new ExaLead::QueryParameter( $qp_xml->{'name'}, $qp_xml->{'value'} ) );
  }
  $self->query = $query;
  
## Parse Groups....
  foreach my $T ( @{$xml->{'Groups'}[0]{'Group'}||[]} ) {
    my $group = new ExaLead::Group( $T->{'title'}, $T->{'count'} );
    $group->link( 'reset' ) = new ExaLead::Link( $T->{'resetHref'}, $self ) if exists $T->{'resetHref'};
    $group->addChildren( $self->_parse_category_tree( $T->{'Category'} ) );
    $self->addGroup( $group );
  }

## Parse Hits....
  $self->nmatches  = $xml->{'Hits'}[0]{'nmatches'};
  $self->nhits     = $xml->{'Hits'}[0]{'nhits'};
  $self->start     = $xml->{'Hits'}[0]{'start'};
  $self->end       = $xml->{'Hits'}[0]{'end'};
  $self->estimated = $xml->{'Hits'}[0]{'estimated'};
  $self->last      = $xml->{'Hits'}[0]{'last'};
  foreach my $hit_xml ( @{$xml->{'Hits'}[0]{'Hit'}||[]} ) {
    my $hit = new ExaLead::Hit( $hit_xml->{'url'}, $hit_xml->{'score'} );
    foreach my $hit_field_xml ( @{$hit_xml->{'HitField'}||[]} ) {
      my $name = $hit_field_xml->{'name'};
      if( exists($hit_field_xml->{'TextSeg'} ) ) {
        my $TS = new ExaLead::TextSeg();
        foreach my $ts_xml ( @{$hit_field_xml->{'TextSeg'}} ) {
          $TS->addPart($ts_xml->{'content'}||' ', $ts_xml->{'highlighted'});
        }
        $hit->addField( $name, $TS );
      } elsif( exists($hit_field_xml->{'value'} ) ) {
        my $TS = new ExaLead::Value( $hit_field_xml->{'value'}, $query );
        $hit->addField( $name, $TS );
      }
    } 
    foreach my $hit_group_xml( @{$hit_xml->{'HitGroup'}||[]} ) {
      my $hitgroup = new ExaLead::HitGroup( $hit_group_xml->{'title'} );
      $hitgroup->addChildren( $self->_parse_hit_category_tree( $hit_group_xml->{'HitCategory'} ) );
      $hit->addGroup( $hitgroup );
    }
    $self->addHit( $hit );
  }
## Parse spelling suggestions....
  foreach my $spelling_xml ( @{$xml->{'SpellingSuggestions'}[0]{'SpellingSuggestion'}||[]} ) {
    foreach my $T ( @{$spelling_xml->{'SpellingSuggestionVariant'}||[]} ) {
      $self->addSpellingSuggestion( new ExaLead::SpellingSuggestion( 
        $T->{'query'}, $T->{'display'}
      ));
    }
  }
## Parse relevant keywords....
  foreach my $k_xml ( @{$xml->{'Keywords'}[0]{'Keyword'}||[]} ) {
    my $K = new ExaLead::Keyword( $k_xml->{'display'}, $k_xml->{'count'} );
    my @links = qw( exclude reset refine );
    foreach my $n ( @links ) {
      $K->link( $n ) = new ExaLead::Link( $k_xml->{ $n."Href" }, $self ) if exists( $k_xml->{$n."Href"} );
    }
    $self->addKeyword( $K );
  }
}

sub _parse_category_tree {
### Recursive parser for the main category trees (stored in {{Exalead::Group}} object)
  my( $self, $category ) = @_;
  my @links = qw( exclude reset refine );
  my $cat_array = [];
  foreach my $cat (@$category) {
    my $entry = new ExaLead::Category( $cat->{'name'}, $cat->{'count'}, $cat->{'gcount'} );
    foreach my $n ( @links ) {
      $entry->link( $n ) = new ExaLead::Link( $cat->{ $n."Href" }, $self ) if exists( $cat->{$n."Href"} );
    }
    $entry->addChildren( $self->_parse_category_tree( $cat->{'Category'} ) ) if exists $cat->{'Category'};
    push @$cat_array, $entry;
  }
  return $cat_array;
}

sub _parse_hit_category_tree {
### Recursive parser for the hit category trees (stored in {{Exalead::Hit}} object)
  my( $self, $category ) = @_;
  my $cat_array = [];
  foreach my $cat (@$category) {
    my $entry = new ExaLead::HitCategory( $cat->{'name'} );
    $entry->link( 'browse' ) = new ExaLead::Link( $cat->{ "browseHref" }, $self ) if exists $cat->{"browseHref"};
    $entry->addChildren( $self->_parse_hit_category_tree( $cat->{'HitCategory'} ) ) if exists $cat->{'HitCategory'};
    push @$cat_array, $entry;
  }
  return $cat_array;
}

1;
