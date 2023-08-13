def solution(number):
    if number < 0:
        return 0
    
    multiples = set([0])
    num = 0
    
    while num < number:
        if (num%3) is 0:
            multiples.add(num)
            num = num + 1
        elif (num%5) is 0:
            multiples.add(num)
            num = num + 1
        else:
            num = num + 1
    
    final = sum(multiples)
    return final
