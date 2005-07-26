# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::IO::Analysis;

=head1 NAME

  GO::IO::Analysis     - preliminary analysis object

=head1 SYNOPSIS



=cut



=head1 DESCRIPTION

top level module for doing analyses eg clustalw on the fly

=head1 CREDITS


=head1 PUBLIC METHODS


=cut


use strict;
use base qw(GO::Model::Root);
use GO::Utils qw(rearrange);
use GO::IO::Blast;

sub _valid_params { qw() };


sub clustalw {
    my $self = shift;
    my ($products, $seqs, $seqf) = rearrange([qw(products seqs file)], @_);
    
    my $leave = $seqf ? 1 : 0;

    if (!$seqs) {
        $seqs = [];
	my %h = ();
        foreach my $p (@$products) {
            push(@$seqs, 
		 grep {
		     !$h{$_->display_id} && ($h{$_->display_id} = 1)
		 } @{$p->seq_list});
        }
    }

    # TODO : use displatcher class to allow 
    # other ways of calling programs

    my $seqf = $seqf || "/tmp/$$.clustalin.fa";
    my $outf = $seqf;
    $outf =~ s/fa$/aln/;
    open(F, ">$seqf") || die;
    map {print F $_->to_fasta} @$seqs;
    close(F);
    
    my $cmd = "clustalw -infile=$seqf -outfile=$outf";
    print "cmd=$cmd\n";
    print `$cmd`;

    open(F, "$outf") || die;
    my $out = join("", <F>);
    close(F);

    unless ($leave) {
        unlink $seqf;
        unlink $outf;
    }
    
    return $out;
}

sub blastp {
    my $self = shift;
    my ($fn) = rearrange([qw(file)], @_);
    

    # TODO : use displatcher class to allow 
    # other ways of calling programs


    #HARDCODE ALERT!!!!!!!!!!!!!!!!!!!!
    # this is a still a VERY preliminary module
    my $db = "/www/whitefly_80/WWW/annot/go/fasta/go_pep.fa";
    my $outf = "/tmp/$$.blastout.fa";
#   my $cmd = "blastp $db $fn -filter SEG+XNU > $outf";
    my $cmd = "blastp $db $fn > $outf";
    print "cmd=$cmd\n";
    print `$cmd`;

    my $blast = 
      GO::IO::Blast->new({apph=>$self->apph,
                          file=>"$outf"});
    return $blast;
}


=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself

=cut


1;


