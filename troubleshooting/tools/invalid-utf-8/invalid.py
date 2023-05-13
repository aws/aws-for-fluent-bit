# small script that writes byte values to a file
# which if interpreted as utf-8 will be invalid chars
# can test FLB processing of invalid unicode

myfile = open(sys.argv[1], 'ab')

# from https://github.com/fluent/fluent-bit/pull/4297
invalid = b'\xEF\xBF\x00'

# these were copied from invalid utf-8 examples online
# https://stackoverflow.com/questions/1301402/example-invalid-utf8-string
other_invalid_byte_sequence=b'\xC2\xC2\xC0\xC1'
invalid_examples = [
    b'\xc3\x28',
    b'\xa0\xa1',
    b'\xe2\x28\xa1',
    b'\xe2\x82\x28',
    b'\xf0\x28\x8c\xbc',
    b'\xf0\x90\x28\xbc',
    b'\xf0\x28\x8c\x28',
]


myfile.write(bytes('some valid line\n', 'utf-8'))

for i in range(255):
   a_byte = i.to_bytes(1, 'big')
   myfile.write(a_byte)
   myfile.write(invalid)
   myfile.write(other_invalid_byte_sequence)
   for example in invalid_examples:
      myfile.write(example)

myfile.write(bytes('some valid line\n', 'utf-8'))