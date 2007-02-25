package ExaLead::Value;
use strict;
use CGI qw(unescapeHTML);

sub new {
### c
  my( $class, $value, $query ) = @_;
  my $self = { 'value'     => $value, 'query' => $query };
  bless $self, $class;
  return $self;
}

sub value  :lvalue {
### a
  $_[0]->{'value'};
} # get/set string

sub getString {
### Returns a plain (un-highlighted) version of the string for the renderer
### (exhibits same intreface as {{Exalead::TextSeg}})
  return CGI::unescapeHTML( $_[0]->{'value'} );
}

sub getHighlighted {
### Returns a string with query terms tagged with with a highlighted span
### (exhibits same intreface as {{Exalead::TextSeg}}
  my $string = CGI::unescapeHTML( $_[0]->{'value'} ); 
  my @values = split /(<.*?>)/, $string;
  foreach my $qt ( sort { length($b->regexp) <=> length($a->regexp) }  $_[0]->{'query'}->terms ) {
    my @new_values;
    my $R = '('.$qt->regexp.')';
    warn $R. ".... @values ...";
    
    for(my $i=0;$i<@values;$i+=2){ 
      (my $T = $values[$i]) =~ s/$R/<span class="hi">$1<\/span>/ismg;
      push @new_values, split /(<.*?>)/, $T;
      push @new_values, $values[$i+1];
    } 
    @values = @new_values;
  }
  return join "",@values;
}
1;
