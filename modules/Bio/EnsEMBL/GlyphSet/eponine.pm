package Bio::EnsEMBL::GlyphSet::eponine;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;
use IO::Socket;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Eponine TSS',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;
	
	return unless ($self->strand() == -1);
	
	my $SERVER = 'servlet.sanger.ac.uk';
	my $PORT = 8080;
	my $EP_REQUEST1 = 'GET /das/tss_eponine/features?ref=';
	my $EP_REQUEST2 = ' HTTP/1.0';

    my $Config         = $self->{'config'};
    my $feature_colour = $Config->get($Config->script(),'eponine','col');
	my $length = $self->{'container'}->length();

    my @map_contigs = ();
	my %eplist = ();
	my $i = 0;
	@map_contigs = $self->{'container'}->_vmap->each_MapContig();
    if (@map_contigs){
		my $start = $map_contigs[0]->start();
    	my $end   = $map_contigs[-1]->end();
    	my $tot_width = $end - $start;

   		foreach my $temp_rawcontig ( @map_contigs ) {

        	my $socket = IO::Socket::INET->new(PeerAddr => $SERVER,
                    	   PeerPort => $PORT,
                    	   Proto    => 'tcp',
                    	   Type     => SOCK_STREAM,
                    	   Timeout  => 10,
                    	   ) or warn("Cannot make socket to $SERVER on port $PORT!\n");

			my $REQ = "$EP_REQUEST1" . $temp_rawcontig->contig->id() . "$EP_REQUEST2";
			print $socket "$REQ\n\n";
			my ($s, $e, $o) = undef;
			while(<$socket>){

				if(/<FEATURE id="null">/o){ $eplist{$i} = [];}
        		if(/<START>(\d+)<\/START>/o){ $s = $1;}
        		if(/<END>(\d+)<\/END>/o){ $e = $1;}
        		if(/<ORIENTATION>(.)<\/ORIENTATION>/o){$o = $1;}

				if ($s && $e && $o){
					print STDERR "OK: $s && $e && $o\n";
    				my( $mapcontig,$raw_start,$ori) = $self->{'container'}->raw_contig_position(1,1);
    				if ($o eq '+'){
						$s 		= $self->{'container'}->_global_start + $s - $temp_rawcontig->rawcontig_start();
						$e   	= $self->{'container'}->_global_start + $e - $temp_rawcontig->rawcontig_start();
    				}
    				else {
						my $s2 	= $self->{'container'}->_global_start + $temp_rawcontig->rawcontig_start() - $e;
						my $e2  = $self->{'container'}->_global_start + $temp_rawcontig->rawcontig_start() - $s;
						$s = $s2;
						$e = $e2;
    				}
					push @{$eplist{$i}}, ($s,$e);
					$i++;
					($s, $e, $o) = undef;
				}
			}
			close($socket);
						
		}
	}
	
	foreach my $key (keys %eplist){
	
		#print STDERR "$key => ", join(" ", @{$eplist{$key}}), "\n";
		#print STDERR "Length: $length\n";
		#print STDERR "Gstart: ", $self->{'container'}->_global_start(),"\n";
		#print STDERR "Gend: ", $self->{'container'}->_global_end(),"\n";

		my $s = @{$eplist{$key}}->[0];
		my $e = @{$eplist{$key}}->[1];
		my $l = @{$eplist{$key}}->[1] - @{$eplist{$key}}->[0];

		#print STDERR "E start: $s\n";
		#print STDERR "E end: $e\n";
		#print STDERR "E length: $l\n";
		
		if ($s < $self->{'container'}->_global_start || $e > $self->{'container'}->_global_end){
			print STDERR "Bounds error: $s [",$self->{'container'}->_global_start,"], $e [",$self->{'container'}->_global_end,"]\n";
		}
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      		=> $s,
	    	'y'      		=> 0,
	    	'width'  		=> $l,
	    	'height' 		=> 10,
	    	'colour' 		=> $feature_colour,
	    	'absolutey'  	=> 1,
#	    	'zmenu' 		=> {
#				'caption' => 'Transcription start site',
#				'Eponine' => "",
#	    	},
		});
		#print STDERR "Pushing $glyph\n";
		$self->push($glyph);

	}
}


1;
