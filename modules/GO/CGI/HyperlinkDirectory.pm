package GO::CGI::NameMunger;

use GO::Utils qw(rearrange);

=head1 GO::CGI::NameMunger

This is a helper module to take database abbreviations, 
and produce URL's, human readable names, etc.

Ideally this will soon be done with RDF.  For now
it remains a perl hack.

=head2 get_url

parameters: database_abbreviation, acc_no

returns: url to the entry

get_url takes a database abbreviation from GO and accession
and returns a url to get the page.

=cut

sub get_url {
  my $self = shift;
  my ($database, $acc_no) =
    rearrange(['database', 'acc_no'], @_);

  my $url;

  if ($database eq "sgd") {
    $url = "http://genome-www4.stanford.edu/cgi-bin/SGD/locus.pl?locus=$acc_no";
  }
  elsif ($database eq "mgi") {
    $url = "http://www.informatics.jax.org/searches/accession_report.cgi?id=$acc_no";
  }
  elsif ($database eq "fb") {
    $url = "http://flybase.bio.indiana.edu/.bin/fbidq.html?$acc_no";
  }
  return $url;
}

=head2 get_human_name

parameters: database_abbreviation

returns: url to the entry

get_url takes a database abbreviation from GO and accession
and returns a human freindly name to the datasource.

=cut

sub get_human_name {
  my $self = shift;
  my ($database) =
    rearrange(['database'], @_);
  
  my $dbs = {'fb'=>'FlyBase',
	     'sgd'=>'SGD',
	     'mgi'=>'MGI'
	     };
  
  return $dbs->{$database};
}
1;  
