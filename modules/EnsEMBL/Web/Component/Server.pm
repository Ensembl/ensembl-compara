=head1 NAME

EnsEMBL::Web::Component::Server

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=cut

package EnsEMBL::Web::Component::Server;

use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Form;
use Bio::EnsEMBL::ColourMap;
our $cm;
use base qw(EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

sub display_node {
  my( $panel, $x, $depth ) = @_;
  if( ref( $x ) eq 'HASH' ) {           ## HASH REF....
    $panel->print( '<table class="nested" style="border:1px solid red">' );
    foreach( sort keys %$x ) {
      $panel->printf( '<tr><th>%s</th><td>', encode_entities( $_ ) );
      display_node( $panel, $x->{$_}, $depth + 1 );
      $panel->print( '</td></tr>' );
    }
    $panel->print( '</table>' );
  } elsif( ref( $x ) eq 'ARRAY' ) {     ## ARRAY REF....
    my $C = 0;
    $panel->print( '<table class="nested" style="border:1px solid blue">' );
    foreach( @$x ) {
      $panel->printf( '<tr><th>%d</th><td>', $C++ );
      display_node( $panel, $_, $depth + 1 );
      $panel->print( '</td></tr>' );
    }
    $panel->print( '</table>' );
  } else { ## SCALAR
    $panel->printf( '<div style="border:1px solid green">%s</div>', encode_entities( $x ) );
  }
}

sub tree_form {
  my($panel,$object) = @_;
  my $form = EnsEMBL::Web::Form->new( 'tree', '/'.$object->species.'/tree', 'get' );
  $form->add_element(
    'type'  => 'Information',
    'value' => '<p>Select the file you wish to look at</p>'
  );
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'file',
    'label'    => 'File',
    'values'   => [ map( { { 'value' => $_, 'name' => $_ } } $object->get_all_packed_files )],
    'value'    => $object->param('file')
  );

  $form->add_element( 'type' => 'Submit', 'value' => 'Change' );
  return $form;

}

sub tree {
  my($panel,$object) = @_;
  $panel->printf('<p>Contents of %s.packed</p>', $object->param('file') );
  $panel->print( $panel->form('tree')->render );
  display_node( $panel, $object->unpack_db_tree, 0 );
  return 1;
}
=head2 name

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the release version and site type

=cut

sub name {
  my($panel,$object) = @_;
  (my $DATE = $object->species_defs->ARCHIVE_VERSION ) =~ s/(\d+)/ $1/;
  $panel->add_row( 'Site summary', qq(<p>@{[$object->species_defs->ENSEMBL_SITETYPE]} - $DATE</p>) );
  return 1;
}

=head2 url

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the website root URL

=cut

sub url {
  my($panel,$object) = @_;
  $panel->add_row( 'Web address', qq(<p>@{[ $object->full_URL( 'species' => '' ) ]}</p>) );
  return 1;
}

=head2 version

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the Ensembl API version

=cut

sub version {
  my($panel,$object) = @_;
  $panel->add_row( 'Version', qq(<p>@{[$object->species_defs->ENSEMBL_VERSION]}</p>) );
  return 1;
}

=head2 webserver

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the web server information

=cut

sub webserver {
  my($panel,$object) = @_;
  $panel->add_row( 'Web server', qq(<p>$ENV{'SERVER_SOFTWARE'}</p>) );
  return 1;
}

=head2 perl

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the perl version

=cut

sub perl {
  my($panel,$object) = @_;
  my $perl_version = $];
  my $m1 = int($]);
  my $m2 = ($]*1000)%1000;
  my $m3 = ($]*1e6)%1000;
  $panel->add_row( 'Perl', qq(<p>$m1.$m2.$m3</p>) );
  return 1;
}

=head2 contact

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the server administrator.

=cut

sub contact {
  my($panel,$object) = @_;
  my $EM = $object->species_defs->ENSEMBL_SERVERADMIN;
  $panel->add_row( 'Contact info', sprintf qq(<p><a href="mailto:%s">%s</a></p>),$EM,$EM );
  return 1;
}

=head2 database

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the database version

=cut


sub database {
  my($panel,$object) = @_;
## Get the version comment (e.g. MySQL...)
  my $sth2 = $object->database( 'core' )->dbc->prepare("show variables like 'version_comment'");
     $sth2->execute();
  my ($X, $db) = $sth2->fetchrow_array();
     $sth2->finish;
  
## Get the version number of the database.... (e.g. 4.1.12)
  my $sth = $object->database( 'core' )->dbc->prepare("select version()");
     $sth->execute();
  my ($version) = $sth->fetchrow_array();
     $sth->finish;
  if( $version =~ /(\d+\.\d+\.\d+)/ ) { $version = $1; };

## Display these
  $panel->add_row( 'Database', qq(<p>$db<br />Version: $version</p>) );
  return 1;
}

sub spreadsheet_Species {
  my( $panel, $object ) = @_;
  $panel->add_columns(
    {  'key' => 'species', 'align' => 'left', 'title' => 'Species',
      'format' => sub { return sprintf( qq(<a href="%s"><i>%s</i></a>), $_[1]{'link'}, $_[0] ) } },
    {  'key' => 'common',  'align' => 'left', 'title' => 'Common name' },
    {  'key' => 'gp',      'align' => 'left', 'title' => 'Golden Path' },
    {  'key' => 'version', 'align' => 'left', 'title' => 'Version' }
  );
  foreach( $object->get_all_species ) { $panel->add_row( $_ ); }
  return 1;
}


sub spreadsheet_Colours {
  my( $panel, $object ) = @_;
  $panel->add_columns(
    { 'align' => 'center', 'key' => 'name',       'title' => 'Name'} ,
    { 'align' => 'center', 'key' => 'black',      'title' => 'On black' },
    { 'align' => 'center', 'key' => 'white',      'title' => 'On white' },
    { 'align' => 'center', 'key' => 'background', 'title' => 'As background' },
    { 'align' => 'center', 'key' => 'hex',        'title' => 'HEX' },
    { 'align' => 'center', 'key' => 'rgb',        'title' => 'RGB' },
    { 'align' => 'center', 'key' => 'hls',        'title' => 'HLS' },
    defined( $object->param('hex') ) ? {  'align' => 'right', 'key' => 'dist', 'title' => 'Distance' } : ()
  );
  my $colour  = $object->param('hex');
  my $hls     = $object->param('hls');
  my $sort_by = $object->param('sort');
  $cm ||= new Bio::EnsEMBL::ColourMap( $object->species_defs );
  my @keys;

  my @r_rgb = (255,0,0);
  if(defined($colour)) {
    @r_rgb = $cm->rgb_by_hex($colour);
  }
  my %rgb = map { ( $_, [ $cm->rgb_by_hex( $cm->{$_} ) ] ) } keys %$cm;
  my %hls = map { ( $_, [ hls(@{$rgb{$_}},@r_rgb )   ] ) } keys %$cm;
  if(defined $hls) {
    @keys = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map {
      [ &sortby_hls( $hls{$_}, $hls) , $_ ]
    } keys %$cm;
  } elsif(defined $colour) {
     @keys = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map {
       [ &coldist( $rgb{$_}, \@r_rgb ) , $_ ]
     } keys %$cm;
  } elsif( defined $sort_by ) {
     @keys = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map {
       [ &sortby( $rgb{$_}, $sort_by ) , $_ ]
     } keys %$cm;
  } else {
    @keys = sort keys %$cm;
  }
  foreach my $k ( @keys ) {
    next if $k eq 'colour_sets';
    my $v = $cm->{$k};
    my ($r,$g,$b) = @{$rgb{$k}};
    my ($h,$l,$s) = @{$hls{$k}};
    my $c = $cm->contrast($k);
    $panel->add_row(
      { 'name' => $k,
        'black' => qq(<div style="margin: 0px auto; width: 10em; background-color: #000; color: #$v">$k</div>),
        'white' => qq(<div style="margin: 0px auto; width: 10em; background-color: #fff; color: #$v">$k</div>),
        'background' => qq(<div style="margin: 0px auto; width: 10em; background-color: #$v; color: $c">$k</div>),
        'hex'   => "<tt>$v</tt>",
        'rgb'   => space2nbsp( sprintf( '<tt>(%3d,%3d,%3d)</tt>', $r,$g,$b ) ),
        'hls'   => space2nbsp( sprintf( '<tt>(%4d,%3d,%3d)</tt>', $h,$l,$s ) ),
        'dist'  => defined($colour) ? sprintf( '%0.3f', coldist( $rgb{$k},\@r_rgb ) ) : 0
      }
    );
  }
  return 1;
}

sub space2nbsp { (my $T = $_[0]) =~ s/ /&nbsp;/g; return $T; }

sub coldist {
  my( $hr,$hg,$hb,$gr,$gg,$gb ) = (@{$_[0]},@{$_[1]});
  my $d = sqrt(($hr-$gr)*($hr-$gr)+($hg-$gg)*($hg-$gg)+($hb-$gb)*($hb-$gb))/sqrt(3)/255;
  return $d;
}

sub sortby {
  my( $h, $order ) = @_;
  my %h;
  ($h{'r'}, $h{'g'}, $h{'b'}) = @$h;
  my $V = 0;
  foreach ( split '',$order ) { $V = $V*1000 + $h{$_}; }
  return -$V;
}

sub sortby_hls {
  my( $h, $order ) = @_;
  my %h;
  ($h{'h'}, $h{'l'}, $h{'s'}) = @$h;
  my $V = 0;
  foreach ( split '',$order ) { $V = $V*1000 + $h{$_}; }
  return -$V;
}

sub hls {
  my( $r,$g,$z,$R,$G,$Z ) = @_;
  my ($mi,$x,$ma) = sort {$a<=>$b} ($r,$g,$z);
  my $l = ($r+$g+$z)/765;
  return (0,int(100*$l),0) if $mi==$ma;

  my $L = ($R+$G+$Z)/765;
  my ($MI,$X,$MA) = sort {$a<=>$b} ($R,$G,$Z);
  if($MI == $MA) {
    $R=255;
    $G=0;
    $Z=0;
    $L=1/3;
  }

  my $s = 1 - $mi/255/$l;

  ($r,$g,$z) = ( $r/$l/765-1/3, $g/$l/765-1/3, $z/$l/765-1/3 );
  ($R,$G,$Z) = ( $R/$L/765-1/3, $G/$L/765-1/3, $Z/$L/765-1/3 );
  my $d = sqrt($r*$r+$g*$g+$b*$b);
  my $D = sqrt($R*$R+$G*$G+$Z*$Z);

  my $c_th = ($r*$R+$g*$G+$b*$Z)/$d/$D;
  my $s_th = ($r*$G-$g*$R+$g*$Z-$b*$G+$b*$R-$r*$Z)/$d/$D;

  my $h = atan2($s_th,$c_th);
  return( int($h*180/3.14159), int($l*100), int($s*100) );
}

sub colourmap_usage {
  my( $panel, $object ) = @_;
  $panel->add_row( 'Usage' => qq(
<dl>
<dt>hex  = 'xxxxxx' (6 digit hex value....)</dt>
<dd>if hls parameter is set uses this colour as the centre point for the hue calculation.</dd>
<dd>otherwise displays colours according to euclidean distance from this value</dd>
<dt>hls  = any combination of 'h','l' and 's'</dt>
<dd>displays colours sorted by HLS values, sort is ordered according to these, e.g.  h,l sort by hue, then by luminosity</dd>
<dt>sort = any combination of 'r','g' and 'b'</dt>
<dd>displays colours sorted by rgb values</dd>
</dl>) );
  return 1;
}

sub urlsource_form {
  my( $panel, $object ) = @_;
  my $script = $object->param( 'script' );
  my $form = EnsEMBL::Web::Form->new( 'urlsource', "/@{[$object->species]}/$script", 'get' );
  $form->add_attribute( 'onSubmit', sprintf(
    qq(if(on_submit(%s_vars)) { window.opener.location='/%s/%s?l=%s&c=%s&w=%s&h=%s&data_URL='+this.data_URL.value; window.close(); return 1 } else { return 0 }),
    'urlsource', $object->species, $script, $object->param('l'), $object->param('c'), $object->param('w'), encode_entities( join('|',$object->param('h'),$object->param('highlight') ) )
  ) );
  $form->add_element(
    'type'  => 'Information',
    'value' => '<p>This dialog allows you to attach a local web-based data-source to the Ensembl ContigView and CytoView displays</p>'
  );
  $form->add_element( 'type' => 'Hidden', 'name' => 'l', 'value' => $object->param('l') ) if defined $object->param('l');
  $form->add_element( 'type' => 'Hidden', 'name' => 'c', 'value' => $object->param('c') ) if defined $object->param('c');
  $form->add_element( 'type' => 'Hidden', 'name' => 'w', 'value' => $object->param('w') ) if defined $object->param('w');
  $form->add_element( 'type' => 'Hidden', 'name' => 'h', 'value' => join('|',$object->param('h'),$object->param('highlight')) )
    if defined $object->param('h') || defined $object->param('highlight');
  $form->add_element(
    'type' => 'URL', 'required' => 'yes',
    'label' => "Date URL:",  'name' => 'data_URL',
    'value' => "http://",
  );
  $form->add_element( 'type' => 'Submit', 'value' => 'Add source' );
  return $form;
}

sub urlsource {
  my( $panel, $object ) =@_;
  $panel->print( $panel->form('urlsource')->render );
  return 1;
}

1;    


