#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate the Edu Oasis PDPA notice PDF (Akta Perlindungan Data Peribadi 2010)."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT, TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

pdfmetrics.registerFont(TTFont('NotoSerif', '/usr/share/fonts/truetype/noto-serif-sc/NotoSerifSC-Regular.ttf'))
pdfmetrics.registerFont(TTFont('NotoSans', '/usr/share/fonts/truetype/chinese/NotoSansSC-Regular.ttf'))

OUT = '/home/z/my-project/download/PDPA_Notis_Edu_Oasis.pdf'

styles = {
    'title': ParagraphStyle('title', fontName='NotoSans', fontSize=18, leading=24, alignment=TA_CENTER, spaceAfter=4),
    'sub':   ParagraphStyle('sub', fontName='NotoSans', fontSize=10, leading=14, alignment=TA_CENTER, textColor='#0e7c66', spaceAfter=10),
    'h2':    ParagraphStyle('h2', fontName='NotoSans', fontSize=12, leading=16, spaceBefore=10, spaceAfter=4, textColor='#04141d'),
    'body':  ParagraphStyle('body', fontName='NotoSerif', fontSize=10.5, leading=16, alignment=TA_JUSTIFY, spaceAfter=6),
    'small': ParagraphStyle('small', fontName='NotoSerif', fontSize=9, leading=13, textColor='#555555', spaceAfter=4),
}

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=22*mm, rightMargin=22*mm, topMargin=20*mm, bottomMargin=18*mm,
                        title='Notis PDPA - Edu Oasis', author='Edu Oasis Training Sdn Bhd')

E = []
E.append(Paragraph('Notis Perlindungan Data Peribadi', styles['title']))
E.append(Paragraph('Edu Oasis Training Sdn Bhd &nbsp;·&nbsp; Pindaan v1.0 &nbsp;·&nbsp; 16 November 2026', styles['sub']))
E.append(HRFlowable(width='100%', thickness=1.2, color='#10b981', spaceBefore=2, spaceAfter=10))

E.append(Paragraph('Pengenalan', styles['h2']))
E.append(Paragraph(
    'Notis ini dikeluarkan selaras dengan <b>Akta Perlindungan Data Peribadi 2010</b> (Akta 709) dan peraturan '
    'pelaksanaannya di Malaysia. Edu Oasis Training Sdn Bhd ("Edu Oasis", "kami") sebagai Pengawal Data '
    'berkomitmen untuk melindungi data peribadi yang dikumpul, diproses dan disimpan melalui Platform Latihan '
    'Edu Oasis (LMS) termasuk modul Latihan Awam NON-HRD dan Kursus Layak Tuntutan e-TRiS (HRD Corp).', styles['body']))

E.append(Paragraph('Jenis Data Peribadi yang Dikumpul', styles['h2']))
E.append(Paragraph(
    'Kami mengumpul data peribadi yang berkaitan dengan pendaftaran dan penyertaan program latihan, termasuk: '
    'nama penuh, nombor kad pengenalan/pasport, alamat e-mel, nombor telefon, jawatan, maklumat majikan '
    '(nama syarikat, no. SSM, ID Majikan HRD Corp), rekod kehadiran, keputusan penilaian, serta maklumat '
    'pembayaran dan bukti transaksi. Untuk jalur HRD Corp, data turut dikongsikan dengan HRD Corp bagi tujuan '
    'tuntutan levi e-TRiS selaras dengan keperluan pengiktirafan program.', styles['body']))

E.append(Paragraph('Tujuan Pemprosesan Data', styles['h2']))
E.append(Paragraph(
    'Data peribadi anda diproses bagi tujuan: (i) mendaftar dan mengurus penyertaan kursus; (ii) menjana invois, '
    'resit dan bukti pembayaran; (iii) merekod kehadiran dan keputusan penilaian; (iv) menerbitkan e-sijil '
    'penyertaan; (v) memenuhi keperluan pematuhan dan tuntutan HRD Corp/e-TRiS; dan (vi) komunikasi berkaitan '
    'program, jadual dan maklum balas. Pemprosesan ini adalah perlu untuk melaksanakan kontrak penyertaan '
    'program dan mematuhi kewajipan undang-undang.', styles['body']))

E.append(Paragraph('Pendedahan kepada Pihak Ketiga', styles['h2']))
E.append(Paragraph(
    'Data peribadi tidak akan dijual. Edu Oasis mendedahkan data terhad kepada: HRD Corp (bagi kursus layak '
    'tuntutan), pihak berkuasa yang diwajibkan oleh undang-undang, jurulatih yang mengendali sesi (terhad '
    'kepada senarai peserta dan kehadiran), dan pemproses bayaran/e-boss bagi penjanaan invois. Semua pihak '
    'ketiga terikat dengan kewajipan kerahsiaan.', styles['body']))

E.append(Paragraph('Hak Anda sebagai Subjek Data', styles['h2']))
E.append(Paragraph(
    'Anda berhak untuk: (a) memaklumkan tujuan pemprosesan dan hak akses kepada data anda; (b) memohon '
    'pembetulan data yang tidak tepat; (c) menarik balik persetujuan bagi pemprosesan tertentu (selagi tidak '
    'bertentangan dengan kewajipan undang-undang); dan (d) menghadkan pemprosesan. Permohonan boleh diajukan '
    'kepada Pegawai Perlindungan Data melalui e-mel di bawah.', styles['body']))

E.append(Paragraph('Keselamatan & Penyimpanan', styles['h2']))
E.append(Paragraph(
    'Data peribadi disimpan dalam sistem dengan kawalan akses berdasarkan peranan, penyulitan kata laluan, dan '
    'log audit. Data disimpan selama tempoh yang diperlukan untuk tujuan di atas atau selaras dengan keperluan '
    'undang-undang, selepas itu dipadamkan atau dianonimkan.', styles['body']))

E.append(Paragraph('Hubungi Kami', styles['h2']))
E.append(Paragraph(
    'Pegawai Perlindungan Data, Edu Oasis Training Sdn Bhd<br/>'
    'E-mel: privacy@eduoasis.my &nbsp;·&nbsp; Tel: +603-2278 0700<br/>'
    'Alamat: Lot 12, Jalan Teknologi, Cyberjaya, Selangor, Malaysia.', styles['body']))

E.append(Spacer(1, 8))
E.append(HRFlowable(width='100%', thickness=0.6, color='#cccccc', spaceAfter=6))
E.append(Paragraph(
    'Dengan menandai kotak "Saya bersetuju dengan Akta Perlindungan Data Peribadi 2010 (PDPA)" pada borang '
    'pendaftaran, anda mengakui telah membaca dan memahami notis ini serta bersetuju Edu Oasis memproses data '
    'peribadi anda selaras dengan tujuan di atas. (Dokumen DEMO — untuk prototaip sahaja.)', styles['small']))

doc.build(E)
print('PDPA PDF written ->', OUT)
