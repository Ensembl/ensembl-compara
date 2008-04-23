package EnsEMBL::Web::Document::HTML::StaticGlobalContext;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub render {
  my $self = shift;

  my @links = ({'URL'=>'/', 'txt'=>'Home'});
  if ($ENV{'ENSEMBL_SPECIES'}) {
    (my $pretty_name = $ENV{'ENSEMBL_SPECIES'}) =~ s/_/ /g;
    push @links, {'URL'=>'/'.$ENV{'ENSEMBL_SPECIES'}.'/', 'txt'=>$pretty_name, 'current'=>'yes'};
  }
  else {
    push @links, {'URL'=>'/species.html', 'txt'=>'Find a species'};
  }
  if ($ENV{'SCRIPT_NAME'} eq '/index.html') {
    $links[0]{'current'} = 'yes';
  }

  $self->print( '
    <dl id="global">' );
  foreach my $link ( @links ) {
    $self->printf( '
      <dd%s><a href="%s">%s</a></dd>',
      $link->{'current'} ? ' class="current"' : '',
      CGI::escapeHTML( $link->{'URL'} ),
      CGI::escapeHTML( $link->{'txt'} )
    );
  }
  $self->print('
    </dl>' );
}

return 1;
